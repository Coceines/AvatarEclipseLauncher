/*
 * Copyright (c) 2010-2017 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "uiminimap.h"
#include "game.h"
#include "luavaluecasts_client.h"
#include "minimap.h"
#include "spritemanager.h"
#include "uimapanchorlayout.h"
#include "map.h"
#include "creature.h"
#include "thingtype.h"
#include "tile.h"

#include "uimapanchorlayout.h"
#include <framework/graphics/shadermanager.h>
#include <cmath>
#include <framework/graphics/painter.h>
#include <framework/graphics/drawqueue.h>

UIMinimap::UIMinimap() {
  m_zoom = 0;
  m_scale = 1.0f;
  m_minZoom = 0;
  m_maxZoom = 4;
  m_smoothFactor = 0.12f; // Camera smoothing (lower = faster)
  m_visualCameraX = 0.0f;
  m_visualCameraY = 0.0f;
  m_layout =
      UIMapAnchorLayoutPtr(new UIMapAnchorLayout(static_self_cast<UIWidget>()));
}

void UIMinimap::setLensStrength(float strength) {
  m_lensStrength = std::max(0.0f, std::min(1.0f, strength));
}

// The lens shader magnifies the center of the widget and squeezes the borders,
// so anything that is still measured in the unmodified widget space (mouse
// clicks) has to be pulled back towards the center before being converted to a
// map position: the shader shows, at the point p, the pixel that is at
// center + (p - center) * factor. This is the exact same curve, and the strength
// must match LENS_STRENGTH in data/shaders/map_lens_fragment.frag.
Point UIMinimap::lensAdjustPoint(const Point &point) {
  const Rect rect = getPaddingRect();
  if (m_lensStrength <= 0.0f || rect.isEmpty())
    return point;

  const Point center = rect.center();
  const float halfW = std::max(1.0f, rect.width() / 2.0f);
  const float halfH = std::max(1.0f, rect.height() / 2.0f);
  const float dx = (float)(point.x - center.x);
  const float dy = (float)(point.y - center.y);
  const float radius = std::sqrt(dx * dx + dy * dy);
  if (radius <= 0.0001f)
    return point;

  // Single divisor (the corner radius), same as the shader: using the distance
  // to the border here would make the correction depend on the axis.
  const float maxRadius =
      std::max(std::sqrt(halfW * halfW + halfH * halfH), 1.0f);
  const float t = std::min(1.0f, radius / maxRadius);
  const float factor = 1.0f - m_lensStrength * (1.0f - t);

  return Point(center.x + (int)std::lround(dx * factor),
               center.y + (int)std::lround(dy * factor));
}

void UIMinimap::draw(const Rect &visibleRect, Fw::DrawPane drawPane) {
  // Sem shader (nome errado ou falha de compilacao) desenha do jeito normal: o
  // caminho do framebuffer nao desenha nada sem shader, e o mapa sumiria.
  if (m_shader.empty() || drawPane != Fw::ForegroundPane ||
      !g_shaders.getShader(m_shader)) {
    UIWidget::draw(visibleRect, drawPane);
    return;
  }

  // Everything this widget draws (map, cross, marks) goes to its own queue,
  // which is later replayed into an offscreen buffer and warped by the shader.
  std::shared_ptr<DrawQueue> queue = std::make_shared<DrawQueue>();
  std::shared_ptr<DrawQueue> previousQueue = g_drawQueue;
  g_drawQueue = queue;
  UIWidget::draw(visibleRect, drawPane);
  g_drawQueue = previousQueue;

  g_drawQueue->add(
      new DrawQueueItemFramebufferWithShader(queue, getPaddingRect(), m_shader));
}

void UIMinimap::drawSelf(Fw::DrawPane drawPane) {
  UIWidget::drawSelf(drawPane);

  if (drawPane != Fw::ForegroundPane)
    return;

  // Force layout update for smooth widgets (flags)
  // Minimap offset changes every frame during walk, so widgets must re-anchor
  m_layout->update();

  g_minimap.draw(getPaddingRect(), m_cameraPosition, m_scale, m_color,
                 calculateSmoothOffset());

  // Tactical view: render players (outfit real) quando zoom in detalhe
  if (m_zoom >= 3) {
    int floor = m_cameraPosition.z;
    if (floor < 0 || floor > Otc::MAX_Z) return;
    Rect widgetRect = getPaddingRect();

    const int MAX_PLAYERS_RENDER = 15;
    const int MAX_TILE_DIST = 15;
    int rendered = 0;
    int _maxDist = 15;
    auto _creatures = g_map.getSpectatorsInRange(m_cameraPosition, false, _maxDist, _maxDist);
    for (const auto& cr : _creatures) {
      if (!cr || !cr->isPlayer()) continue;
      if (rendered >= MAX_PLAYERS_RENDER) break;
      const Position& p = cr->getPosition();
      if (p.z != floor) continue;
      int dx = std::abs(p.x - m_cameraPosition.x);
      int dy = std::abs(p.y - m_cameraPosition.y);
      if (dx > MAX_TILE_DIST || dy > MAX_TILE_DIST) continue;
      Rect r = getTileRect(p);
      if (!r.isValid()) continue;
      Point c = r.center();
      if (!widgetRect.contains(c)) continue;
      const int OUTFIT_SIZE = 32;
      const int X_OFFSET = 8;
      const int Y_OFFSET = 8;
      Rect outfitRect(c.x - OUTFIT_SIZE/2 - X_OFFSET, c.y - OUTFIT_SIZE/2 - Y_OFFSET, OUTFIT_SIZE, OUTFIT_SIZE);
      bool animateOutfit = cr->isWalking();
      Otc::Direction dir = cr->getDirection();
      cr->drawOutfit(outfitRect, dir, Color::white, animateOutfit, true, false);
      rendered++;
    }
  }
}

PointF UIMinimap::calculateSmoothOffset(const Position &targetPos) {
  PointF offset(0, 0);
  if (m_secondaryView)
    return PointF(m_secondaryOffsetX, m_secondaryOffsetY);
  PlayerPtr localPlayer = g_game.getLocalPlayer();
  if (localPlayer) {
    Point walkOffset = localPlayer->getWalkOffset();
    // Scale offset from sprite size to minimap scale
    float offsetScale = (float)m_scale / g_sprites.spriteSize();
    // Use floats for offset
    offset.x = walkOffset.x * offsetScale;
    offset.y = walkOffset.y * offsetScale;

    // Fix: If for local player, ignore offset to keep it centered/smooth
    if (targetPos.isValid() && targetPos == localPlayer->getPosition())
      offset = PointF(0, 0);
  }
  return offset;
}

bool UIMinimap::setZoom(int zoom) {
  if (zoom == m_zoom)
    return true;

  if (zoom < m_minZoom || zoom > m_maxZoom)
    return false;

  // Guard: prevent scale from underflowing to infinity at extreme zoom
  // (was causing GPU crash in drawTexturedRect when scale >> 1).
  int absZoom = std::abs(zoom);
  if (absZoom > 12)
    return false;

  int oldZoom = m_zoom;
  m_zoom = zoom;
  if (m_zoom < 0)
    m_scale = 1.0f / (1 << absZoom);
  else if (m_zoom > 0)
    m_scale = 1.0f * (1 << absZoom);
  else
    m_scale = 1;
  m_layout->update();

  onZoomChange(zoom, oldZoom);
  return true;
}

void UIMinimap::setCameraPosition(const Position &pos) {
  Position oldPos = m_cameraPosition;
  m_cameraPosition = pos; // Direct assignment, no target indirection
  m_layout->update();
  onCameraPositionChange(pos, oldPos);
}

bool UIMinimap::floorUp() {
  Position pos = getCameraPosition();
  if (!pos.up())
    return false;
  // Guard: don't allow risky floor transitions directly from the minimap.
  // Floor changes should be driven by server messages only.
  return false;
}

bool UIMinimap::floorDown() {
  Position pos = getCameraPosition();
  if (!pos.down())
    return false;
  return false;
}

Point UIMinimap::getTilePoint(const Position &pos) {
  return g_minimap.getTilePoint(pos, getPaddingRect(), getCameraPosition(),
                                m_scale, calculateSmoothOffset(pos));
}

Rect UIMinimap::getTileRect(const Position &pos) {
  return g_minimap.getTileRect(pos, getPaddingRect(), getCameraPosition(),
                               m_scale, calculateSmoothOffset(pos));
}

Position UIMinimap::getTilePosition(const Point &mousePos) {
  return g_minimap.getTilePosition(lensAdjustPoint(mousePos), getPaddingRect(),
                                   getCameraPosition(), m_scale,
                                   calculateSmoothOffset());
}

void UIMinimap::anchorPosition(const UIWidgetPtr &anchoredWidget,
                               Fw::AnchorEdge anchoredEdge,
                               const Position &hookedPosition,
                               Fw::AnchorEdge hookedEdge) {
  UIMapAnchorLayoutPtr layout = m_layout->static_self_cast<UIMapAnchorLayout>();
  VALIDATE(layout);
  layout->addPositionAnchor(anchoredWidget, anchoredEdge, hookedPosition,
                            hookedEdge);
}

void UIMinimap::fillPosition(const UIWidgetPtr &anchoredWidget,
                             const Position &hookedPosition) {
  UIMapAnchorLayoutPtr layout = m_layout->static_self_cast<UIMapAnchorLayout>();
  VALIDATE(layout);
  layout->fillPosition(anchoredWidget, hookedPosition);
}

void UIMinimap::centerInPosition(const UIWidgetPtr &anchoredWidget,
                                 const Position &hookedPosition) {
  UIMapAnchorLayoutPtr layout = m_layout->static_self_cast<UIMapAnchorLayout>();
  VALIDATE(layout);
  layout->centerInPosition(anchoredWidget, hookedPosition);
}

void UIMinimap::onZoomChange(int zoom, int oldZoom) {
  callLuaField("onZoomChange", zoom, oldZoom);
}

void UIMinimap::onCameraPositionChange(const Position &position,
                                       const Position &oldPosition) {
  callLuaField("onCameraPositionChange", position, oldPosition);
}

void UIMinimap::onStyleApply(const std::string &styleName,
                             const OTMLNodePtr &styleNode) {
  UIWidget::onStyleApply(styleName, styleNode);
  for (const OTMLNodePtr &node : styleNode->children()) {
    if (node->tag() == "zoom")
      setZoom(node->value<int>());
    else if (node->tag() == "max-zoom")
      setMaxZoom(node->value<int>());
    else if (node->tag() == "min-zoom")
      setMinZoom(node->value<int>());
  }
}
