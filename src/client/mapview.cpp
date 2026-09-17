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

#include "mapview.h"

#include "creature.h"
#include "map.h"
#include "tile.h"
#include "statictext.h"
#include "animatedtext.h"
#include "missile.h"
#include "lightview.h"
#include "localplayer.h"
#include "game.h"
#include "spritemanager.h"

#include <framework/core/clock.h>
#include <framework/graphics/graphics.h>
#include <framework/graphics/image.h>
#include <framework/graphics/framebuffermanager.h>
#include <framework/core/eventdispatcher.h>
#include <framework/core/application.h>
#include <framework/core/resourcemanager.h>
#include <framework/graphics/texturemanager.h>
#include <framework/graphics/atlas.h>
#include <framework/graphics/shadermanager.h>
#include <framework/graphics/painter.h>
#include <framework/graphics/coordsbuffer.h>

#include <framework/util/extras.h>
#include <framework/core/adaptiverenderer.h>
#include <framework/core/clock.h>
#include <algorithm>
#include <cmath>
#include <limits>
#include "normalmapmanager.h"

// ---------------------------------------------------------------------------
// Luz do ambiente
//
// O client NAO tem valor proprio: a luz do mundo vem do server, que a define
// no config.lua (worldLightLevel / worldLightColor). Com worldLightLevel > 0 o
// server congela a luz nesse nivel e o mundo fica sempre naquela penumbra.
//
// Itens no chao nao iluminam mais (Item::draw) e a luz de tile foi desligada
// (Tile::drawBottom): as unicas fontes de luz sao magias (Effect::draw) e
// criaturas.
// ---------------------------------------------------------------------------

void FloorShadowView::draw()
{
    // Upload the shadow-mask data.  We bind the texture on GL_TEXTURE7
    // (a free unit) so that the painter's GL_TEXTURE0 tracking is never
    // touched — avoids the bug where the atlas texture gets overwritten
    // and the painter skips the rebind on the next drawCache() call.
    glActiveTexture(GL_TEXTURE7);
    m_texture->update();
    glBindTexture(GL_TEXTURE_2D, m_texture->getId());
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, m_mapSize.width(), m_mapSize.height(), 0, GL_RGBA, GL_UNSIGNED_BYTE, m_buffer.data());
    glActiveTexture(GL_TEXTURE0);

    // the mask is aligned to the tile grid (2 texels per tile), so texture
    // coordinates are expressed in sub-tile units of the framebuffer
    const float subTile = g_sprites.spriteSize() / 2.0f;
    const Point offset = m_src.topLeft();
    const Size size = m_src.size();
    CoordsBuffer coords;
    coords.addRect(RectF(m_dest.left(), m_dest.top(), m_dest.width(), m_dest.height()),
                   RectF(offset.x / subTile, offset.y / subTile, size.width() / subTile, size.height() / subTile));

    g_painter->resetColor();
    g_painter->resetTexture();
    g_painter->setColor(m_color);
    g_painter->drawTextureCoords(coords, m_texture);
    g_painter->resetColor();
}

MapView::MapView()
{
    m_lockedFirstVisibleFloor = -1;
    m_cachedFirstVisibleFloor = 7;
    m_cachedLastVisibleFloor = 7;
    m_minimumAmbientLight = 0;
    m_optimizedSize = Size(g_map.getAwareRange().horizontal(), g_map.getAwareRange().vertical()) * g_sprites.spriteSize();

    setVisibleDimension(Size(15, 11));
}

MapView::~MapView()
{
    VALIDATE(!g_app.isTerminated());
}

void MapView::drawTileTexts(const Rect& rect, const Rect& srcRect)
{
    Position cameraPosition = getCameraPosition();
    Point drawOffset = srcRect.topLeft();
    float horizontalStretchFactor = rect.width() / (float)srcRect.width();
    float verticalStretchFactor = rect.height() / (float)srcRect.height();

    auto player = g_game.getLocalPlayer();
    auto floor = player->getPosition().z;
    for (auto& tile : m_cachedVisibleTiles[floor]) {
        Position tilePos = tile->getPosition();
        Point p = transformPositionTo2D(tilePos, cameraPosition) - drawOffset;
        p.x *= horizontalStretchFactor;
        p.y *= verticalStretchFactor;
        p += rect.topLeft();
        p.y += 5;

        tile->drawTexts(p);
    }
}

void MapView::drawTileWidget(const Rect& rect, const Rect& srcRect)
{
    Position cameraPosition = getCameraPosition();
    Point drawOffset = srcRect.topLeft();
    float horizontalStretchFactor = rect.width() / (float)srcRect.width();
    float verticalStretchFactor = rect.height() / (float)srcRect.height();

    auto player = g_game.getLocalPlayer();
    auto floor = player->getPosition().z;
    for (auto& tile : m_cachedVisibleTiles[floor]) {
        Position tilePos = tile->getPosition();
        if (tilePos.z != player->getPosition().z) continue;

        Point p = transformPositionTo2D(tilePos, cameraPosition) - drawOffset;
        p.x *= horizontalStretchFactor;
        p.y *= verticalStretchFactor;
        p += rect.topLeft();

        size_t drawQueueStart = g_drawQueue->size();
        tile->drawWidget(p);
        g_drawQueue->setClip(drawQueueStart, rect);
    }
}

void MapView::drawMapBackground(const Rect& rect, const TilePtr& crosshairTile) {
    Position cameraPosition = getCameraPosition();
    if (m_mustUpdateVisibleTilesCache) {
        updateVisibleTilesCache();
    }

    if (g_game.getFeature(Otc::GameForceLight)) {
        m_drawLight = true;
        m_minimumAmbientLight = 0.05f;
    }

    Rect srcRect = calcFramebufferSource(rect.size());
    g_drawQueue->setFrameBuffer(rect, m_optimizedSize, srcRect);

    if (m_drawLight) {
        // A luz do mundo vem do server (config.lua -> worldLightLevel) e vale
        // para TODOS os andares: sem guarda de SEA_FLOOR, senao o subsolo ficaria
        // quase preto agora que itens nao iluminam mais.
        Light ambientLight = g_map.getLight();

        // Smooth lerp transitions for world light changes
        m_targetLightColor = Color::from8bit(ambientLight.color);
        m_targetLightIntensity = std::max<float>(m_minimumAmbientLight * 255, (float)ambientLight.intensity);

        static ticks_t lastFrameMs = 0;
        ticks_t nowMs = g_clock.millis();
        float dt = (lastFrameMs > 0) ? (float)(nowMs - lastFrameMs) / 1000.f : 0.016f;
        lastFrameMs = nowMs;
        dt = stdext::clamp(dt, 0.001f, 0.1f);

        float lerpSpeed = 1.0f - std::exp(-3.0f * dt); // smooth exponential lerp
        m_smoothLightColor = m_smoothLightColor + (m_targetLightColor - m_smoothLightColor) * lerpSpeed;
        m_smoothLightIntensity = m_smoothLightIntensity + (m_targetLightIntensity - m_smoothLightIntensity) * lerpSpeed;

        uint8_t smoothColor8 = Color::to8bit(m_smoothLightColor);
        uint8_t smoothIntensity = (uint8_t)stdext::clamp(m_smoothLightIntensity, 0.f, 255.f);

        // Build blocking map for light occlusion (walls block light).
        // Uses the very same transform as the tiles themselves so the map
        // aligns 1:1 with the light texture (1 texel = 1 tile).
        const int mapTilesW = m_drawDimension.width();
        const int mapTilesH = m_drawDimension.height();
        const int spriteSize = g_sprites.spriteSize();
        std::vector<bool> blockingMap((size_t)mapTilesW * mapTilesH, false);
        for (auto& tile : m_cachedVisibleTiles[cameraPosition.z]) {
            Point p = transformPositionTo2D(tile->getPosition(), cameraPosition);
            const int tx = p.x / spriteSize;
            const int ty = p.y / spriteSize;
            if (tx >= 0 && tx < mapTilesW && ty >= 0 && ty < mapTilesH) {
                if (tile->isBlocking())
                    blockingMap[(size_t)ty * mapTilesW + tx] = true;
            }
        }

        if (!m_lightTexture || m_lightTexture->getSize() != m_drawDimension)
            m_lightTexture = TexturePtr(new Texture(m_drawDimension, false, true));
        m_lightView = std::make_unique<LightView>(m_lightTexture, m_drawDimension, rect, srcRect, smoothColor8, smoothIntensity, blockingMap);
        // Seed the breathing phase with the camera offset (in pixels) so that
        // screen position + seed == world position. Keeps each light's pulse
        // perfectly stable while the player walks.
        m_lightView->setLightSeed(Point(cameraPosition.x * g_sprites.spriteSize(),
                                        cameraPosition.y * g_sprites.spriteSize()));

        // Populate normal map light data from the same light sources
        if (g_normalMaps.isEnabled()) {
            g_normalMaps.resetLights();

            // Sun comes from upper-left at a horizontal angle
            // for visible directional shadows on flat-normal sprites
            g_normalMaps.setSunLight(0.8f, -0.6f, 0.5f, 1.0f);

            // Add the local player's light as a point light (torch effect)
            auto player = g_game.getLocalPlayer();
            if (player) {
                Light playerLight = player->getLight();
                if (playerLight.intensity > 0) {
                    Point playerScreenPos = transformPositionTo2D(player->getPrewalkingPosition(), cameraPosition);
                    Color lightColor = Color::from8bit(playerLight.color);
                    float radius = playerLight.intensity * g_sprites.spriteSize() * 0.5f;
                    g_normalMaps.addLight(playerScreenPos.x + g_sprites.spriteSize() / 2,
                                          playerScreenPos.y + g_sprites.spriteSize() / 2,
                                          radius, playerLight.intensity / 255.0f,
                                          lightColor.rF(), lightColor.gF(), lightColor.bF());
                }
            }
        }
    }

    for (int z = m_cachedLastVisibleFloor; z >= m_cachedFirstFadingFloor; --z) {
        float fading = 1.0;
        if (m_floorFading > 0) {
            fading = 0.;
            if (m_floorFading > 0) {
                fading = stdext::clamp<float>((float)m_fadingFloorTimers[z].elapsed_millis() / (float)m_floorFading, 0.f, 1.f);
                if (z < m_cachedFirstVisibleFloor)
                    fading = 1.0 - fading;
            }
            if (fading == 0) break;
        }

        size_t floorStart = g_drawQueue->size();
        const bool drawFloorShadow = g_game.getFeature(Otc::GameDrawFloorShadow) &&
                                     cameraPosition.z >= Otc::UNDERGROUND_FLOOR && cameraPosition.z == z;
        const bool floorShadowFade = drawFloorShadow && m_floorShadowFadeWidth > 0.f;
        if (floorShadowFade) {
            if (m_floorShadowMaskDirty) {
                buildFloorShadowMask(cameraPosition);
                m_floorShadowMaskDirty = false;
            }
        } else if (drawFloorShadow) {
            // no fade configured: keep the original hard full-screen shadow
            g_drawQueue->addFilledRect(srcRect, m_floorShadow);
        }
        drawFloor(z, cameraPosition, crosshairTile);
        if (floorShadowFade) {
            // drawn after the current floor so the shadow bleeds smoothly into
            // the current floor edges near holes; lower floors are covered by
            // the mask's full-intensity texels (same as the original behavior)
            g_drawQueue->add(new FloorShadowView(m_floorShadowMaskTexture,
                                                 Size(m_drawDimension.width() * 2, m_drawDimension.height() * 2),
                                                 srcRect, srcRect, m_floorShadow, m_floorShadowMaskBuffer));
        }

        if (fading < 0.99)
            g_drawQueue->setOpacity(floorStart, fading);
    }

} 

void MapView::drawFloor(short floor, const Position& cameraPosition, const TilePtr& crosshairTile)
{
    if (floor < 0 || floor > Otc::MAX_Z)
        return;

    auto& tiles = m_cachedVisibleTiles[floor];

    // Avatar custom: apenas o andar da camera contribui com luz. Assim a luz
    // dos andares de baixo/cima nao interfere na iluminacao do andar atual.
    LightView* lightView = (floor == cameraPosition.z) ? m_lightView.get() : nullptr;
    size_t lightFloorStart = lightView ? lightView->size() : 0;

    // Determine if we should apply floor transparency for this floor.
    // Floors above (lower z) get distance-based fade; same-floor tiles with
    // items whose sprites overlap the player get a flat semi-transparency.
    const bool applyUpperTransparency = m_floorTransparencyEnabled &&
                                        floor < cameraPosition.z;
    const bool applyOccluderTransparency = m_floorTransparencyEnabled &&
                                            floor == cameraPosition.z;

    // Pre-compute player draw position for transparency.
    Point playerDrawPos;
    if (applyUpperTransparency || applyOccluderTransparency) {
        playerDrawPos = transformPositionTo2D(cameraPosition, cameraPosition);
    }

    // light
    if (lightView) {
        for (auto& tile : tiles) {
            Point tileDrawPos = transformPositionTo2D(tile->getPosition(), cameraPosition);
            ItemPtr ground = tile->getGround();
            if (ground && ground->isGround() && !ground->isTranslucent()) {
                lightView->setFieldBrightness(tileDrawPos, lightFloorStart, 0);
            }
        }
    }

    // Ground first: every tile lays down its ground before any bottom item,
    // creature or top thing is drawn.  With the previous single-pass version
    // (ground → bottom → creatures → top, tile by tile) the ground of a tile
    // drawn later — the south/east neighbour — covered the lower part of
    // sprites that overflow their own tile, so walking creatures and effects
    // looked like they were being cut by the floor.
    // Items/creatures keep being drawn tile by tile in the passes below, which
    // preserves the wall/render ordering fixed previously.
    const float spriteSize = (float)g_sprites.spriteSize();
    // Fade radius: m_floorTransparencyRadius (2 SQMs) + 1 SQM for full gradual fade out
    const float fadeRadius = m_floorTransparencyRadius + 1.0f;

    std::vector<float> tileOpacities;
    tileOpacities.reserve(tiles.size());

    for (auto& tile : tiles) {
        Point tileDrawPos = transformPositionTo2D(tile->getPosition(), cameraPosition);

        if (lightView) {
            ItemPtr ground = tile->getGround();
            if (ground && ground->isGround() && !ground->isTranslucent()) {
                lightView->setFieldBrightness(tileDrawPos, lightFloorStart, 0);
            }
        }

        // Calculate smooth progressive transparency fade from one SQM to the next
        float tileOpacity = 1.0f;
        if (applyUpperTransparency) {
            float dx = (float)(tileDrawPos.x - playerDrawPos.x);
            float dy = (float)(tileDrawPos.y - playerDrawPos.y);
            float distTiles = std::sqrt(dx * dx + dy * dy) / spriteSize;

            if (distTiles < fadeRadius) {
                // Progressive linear fade: dist 0 -> 0.30, dist 1 -> 0.53, dist 2 -> 0.77, dist 3 -> 1.00
                float t = distTiles / fadeRadius;
                tileOpacity = m_floorTransparency + (1.0f - m_floorTransparency) * stdext::clamp<float>(t, 0.0f, 1.0f);
            }
        }

        // Same-floor occluder transparency: items on the player's floor whose
        // multi-tile sprites visually overlap the player's screen position
        // (e.g. a tree canopy one tile south covering the player).
        bool occluderApplied = false;
        if (applyOccluderTransparency && tileOpacity >= 0.999f) {
            const Position& tilePos = tile->getPosition();
            const int tdx = tilePos.x - cameraPosition.x;
            const int tdy = tilePos.y - cameraPosition.y;

            // Quick range check — skip tiles too far away to possibly overlap
            if (tdx >= -1 && tdx <= 5 && tdy >= -1 && tdy <= 5) {
                for (const ThingPtr& thing : tile->getThings()) {
                    if (thing->isGround() || thing->isGroundBorder() || thing->isCreature())
                        continue;

                    const int w = thing->getWidth();
                    const int h = thing->getHeight();

                    // Exclude same tile (drawn before creatures, can't visually occlude)
                    if (tdx == 0 && tdy == 0)
                        continue;

                    // Basic bounding-box overlap check
                    if (tdx < 0 || tdx > w - 1 || tdy < 0 || tdy > h - 1)
                        continue;

                    // --- Pixel-level overlap calculation ---
                    // Item sprite on screen (relative to player tile origin):
                    //   X: [(tdx - w + 1) * s .. (tdx + 1) * s]
                    //   Y: [(tdy - h + 1) * s .. (tdy + 1) * s]
                    // Player sprite on screen: [0 .. s] x [0 .. s]
                    const float s = spriteSize;
                    const float oL = std::max(0.0f, (float)(tdx - w + 1) * s);
                    const float oR = std::min(s, (float)(tdx + 1) * s);
                    const float oT = std::max(0.0f, (float)(tdy - h + 1) * s);
                    const float oB = std::min(s, (float)(tdy + 1) * s);
                    const float overlapW = std::max(0.0f, oR - oL);
                    const float overlapH = std::max(0.0f, oB - oT);
                    const float overlapPct = (overlapW * overlapH) / (s * s);

                    // Only trigger when the item's sprite covers at least
                    // the minimum percentage of the player's sprite area
                    if (overlapPct >= m_floorTransparencyThreshold) {
                        tileOpacity = m_floorTransparency;
                        occluderApplied = true;
                        break;
                    }
                }
            }
        }

        tileOpacities.push_back(tileOpacity);

        size_t tileGroundStart = g_drawQueue->size();

        tile->drawGround(tileDrawPos, lightView);

        // Upper-floor fade applies to the ground as well; the same-floor
        // occluder fade must keep the ground fully opaque so the floor beneath
        // stays visible — only the things drawn on top of it get the fade.
        if (tileOpacity < 0.999f && !occluderApplied)
            g_drawQueue->setOpacity(tileGroundStart, tileOpacity);
    }

    // Second pass: bottom items, creatures and top things, tile by tile.
    // The ground of every tile is already on screen, so nothing here can be
    // cut by the floor of the next tile.
    size_t tileIndex = 0;
    for (auto& tile : tiles) {
        Point tileDrawPos = transformPositionTo2D(tile->getPosition(), cameraPosition);

        size_t tileNonGroundStart = g_drawQueue->size();

        tile->drawBottom(tileDrawPos, lightView);

        if (m_crosshair && tile == crosshairTile) {
            g_drawQueue->addTexturedRect(Rect(tileDrawPos, tileDrawPos + g_sprites.spriteSize() - 1),
                                         m_crosshair, Rect(0, 0, m_crosshair->getSize()));
        }

        tile->drawCreatures(tileDrawPos, lightView);
        tile->drawTop(tileDrawPos, lightView);

        // Apply smooth fade transparency to all draw calls of this tile
        const float tileOpacity = tileOpacities[tileIndex++];
        if (tileOpacity < 0.999f)
            g_drawQueue->setOpacity(tileNonGroundStart, tileOpacity);
    }

    // Third pass: magic effects, drawn above everything else of this floor
    // (ground, items and creatures included).
    tileIndex = 0;
    for (auto& tile : tiles) {
        Point tileDrawPos = transformPositionTo2D(tile->getPosition(), cameraPosition);

        size_t effectsStart = g_drawQueue->size();

        tile->drawEffects(tileDrawPos, lightView);

        const float tileOpacity = tileOpacities[tileIndex++];
        if (tileOpacity < 0.999f)
            g_drawQueue->setOpacity(effectsStart, tileOpacity);
    }

    for (const MissilePtr& missile : g_map.getFloorMissiles(floor)) {
        missile->draw(transformPositionTo2D(missile->getPosition(), cameraPosition), true, lightView);
    }
}

void MapView::drawMapForeground(const Rect& rect)
{
    // this could happen if the player position is not known yet
    Position cameraPosition = getCameraPosition();
    if (!cameraPosition.isValid())
        return;

    Rect srcRect = calcFramebufferSource(rect.size());
    Point drawOffset = srcRect.topLeft();
    float horizontalStretchFactor = rect.width() / (float)srcRect.width();
    float verticalStretchFactor = rect.height() / (float)srcRect.height();

    // creatures
    std::vector<std::pair<CreaturePtr, Point>> creatures;
    for (const CreaturePtr& creature : g_map.getSpectatorsInRangeEx(cameraPosition, false, m_visibleDimension.width() / 2, m_visibleDimension.width() / 2 + 1, m_visibleDimension.height() / 2, m_visibleDimension.height() / 2 + 1)) {
        if (!creature->canBeSeen())
            continue;

        PointF jumpOffset = creature->getJumpOffset();
        Point creatureOffset = Point(16 * g_sprites.getOffsetFactor() - creature->getDisplacementX(), -creature->getDisplacementY() - 2 * g_sprites.getOffsetFactor());
        Position pos = creature->getPrewalkingPosition();
        Point p = transformPositionTo2D(pos, cameraPosition) - drawOffset;
        p += (creature->getDrawOffset() + creatureOffset) - Point(jumpOffset.x, jumpOffset.y);
        p.x = p.x * horizontalStretchFactor;
        p.y = p.y * verticalStretchFactor;
        p += rect.topLeft();
        creatures.push_back(std::make_pair(creature, p));
    }

    for (auto& c : creatures) {
        int flags = Otc::DrawIcons;
        if (m_drawNames) { flags |= Otc::DrawNames; }
        if ((!c.first->isLocalPlayer() || m_drawPlayerBars) && !m_drawHealthBarsOnTop) {
            if (m_drawHealthBars) { flags |= Otc::DrawBars; }
            if (m_drawManaBar) { flags |= Otc::DrawManaBar; }
        }
        c.first->drawInformation(c.second, g_map.isCovered(c.first->getPrewalkingPosition(), m_cachedFirstVisibleFloor), rect, flags);
    }

    if (m_lightView) {
        g_drawQueue->add(m_lightView.release());
    }

    // texts
    int limit = g_adaptiveRenderer.textsLimit();
    for (int i = 0; i < 2; ++i) {
        for (const StaticTextPtr& staticText : g_map.getStaticTexts()) {
            Position pos = staticText->getPosition();

            if (pos.z != cameraPosition.z && staticText->getMessageMode() == Otc::MessageNone)
                continue;
            if ((staticText->getMessageMode() != Otc::MessageSay && staticText->getMessageMode() != Otc::MessageYell)) {
                if (i == 0)
                    continue;
            } else if (i == 1)
                continue;

            Point p = transformPositionTo2D(pos, cameraPosition) - drawOffset + Point(8, 0) * g_sprites.getOffsetFactor();
            p.x *= horizontalStretchFactor;
            p.y *= verticalStretchFactor;
            p += rect.topLeft();
            staticText->drawText(p, rect);
            if (--limit == 0)
                break;
        }
    }

    limit = g_adaptiveRenderer.textsLimit();
    for (const AnimatedTextPtr& animatedText : g_map.getAnimatedTexts()) {
        Position pos = animatedText->getPosition();

        if (pos.z != cameraPosition.z)
            continue;

        Point p = transformPositionTo2D(pos, cameraPosition) - drawOffset + Point(16, 8) * g_sprites.getOffsetFactor();
        p.x *= horizontalStretchFactor;
        p.y *= verticalStretchFactor;
        p += rect.topLeft();
        animatedText->drawText(p, rect);
        if (--limit == 0)
            break;
    }

    // tile texts
    drawTileTexts(rect, srcRect);

    // bars on top
    if (m_drawHealthBarsOnTop) {
        for (auto& c : creatures) {
            int flags = 0;
            if ((!c.first->isLocalPlayer() || m_drawPlayerBars)) {
                if (m_drawHealthBars) { flags |= Otc::DrawBars; }
                if (m_drawManaBar) { flags |= Otc::DrawManaBar; }
            }
            c.first->drawInformation(c.second, g_map.isCovered(c.first->getPrewalkingPosition(), m_cachedFirstVisibleFloor), rect, flags);
        }
    }
	
	drawTileWidget(rect, srcRect);

}


void MapView::updateVisibleTilesCache()
{
    int prevFirstVisibleFloor = m_cachedFirstVisibleFloor;
    m_cachedFirstVisibleFloor = calcFirstVisibleFloor(false);
    m_cachedFirstFadingFloor = calcFirstVisibleFloor(true);
    m_cachedLastVisibleFloor = calcLastVisibleFloor();

    VALIDATE(m_cachedFirstVisibleFloor >= 0 && m_cachedLastVisibleFloor >= 0 &&
            m_cachedFirstVisibleFloor <= Otc::MAX_Z && m_cachedLastVisibleFloor <= Otc::MAX_Z);

    if(m_cachedLastVisibleFloor < m_cachedFirstVisibleFloor)
        m_cachedLastVisibleFloor = m_cachedFirstVisibleFloor;

    m_mustUpdateVisibleTilesCache = false;

    // there is no tile to render on invalid positions
    Position cameraPosition = getCameraPosition();
    if (!cameraPosition.isValid()) {
        return;
    }

    // fading
    if (!m_lastCameraPosition.isValid() || m_lastCameraPosition.z != cameraPosition.z || m_lastCameraPosition.distance(cameraPosition) >= 3) { 
        for (int iz = m_cachedLastVisibleFloor; iz >= m_cachedFirstFadingFloor; --iz) {
            m_fadingFloorTimers[iz].restart(m_floorFading * 1000);
        }
    } else if (prevFirstVisibleFloor < m_cachedFirstVisibleFloor) { // showing new floor
        for (int iz = prevFirstVisibleFloor; iz < m_cachedFirstVisibleFloor; ++iz) {
            int shift = std::max<int>(0, m_floorFading - m_fadingFloorTimers[iz].elapsed_millis());
            m_fadingFloorTimers[iz].restart(shift * 1000);
        }
    } else if (prevFirstVisibleFloor > m_cachedFirstVisibleFloor) { // hiding floor
        for (int iz = m_cachedFirstVisibleFloor; iz < prevFirstVisibleFloor; ++iz) {
            int shift = std::max<int>(0, m_floorFading - m_fadingFloorTimers[iz].elapsed_millis());
            m_fadingFloorTimers[iz].restart(shift * 1000);
        }
    }

    m_lastCameraPosition = cameraPosition;

    const int numDiagonals = m_drawDimension.width() + m_drawDimension.height() - 1;
    for (auto& cachedVisibleTiles : m_cachedVisibleTiles) {
        cachedVisibleTiles.clear();
    }

    // draw from last floor (the lower) to first floor (the higher)
    for(int iz = m_cachedLastVisibleFloor; iz >= (m_floorFading ? m_cachedFirstFadingFloor : m_cachedFirstVisibleFloor); --iz) {
        for (int diagonal = 0; diagonal < numDiagonals; ++diagonal) {
            // loop current diagonal tiles
            int advance = std::max<int>(diagonal - m_drawDimension.height(), 0);
            for (int iy = diagonal - advance, ix = advance; iy >= 0 && ix < m_drawDimension.width(); --iy, ++ix) {
                // position on current floor
                //TODO: check position limits
                Position tilePos = cameraPosition.translated(ix - m_virtualCenterOffset.x, iy - m_virtualCenterOffset.y);
                // adjust tilePos to the wanted floor
                tilePos.coveredUp(cameraPosition.z - iz);
                if (const TilePtr& tile = g_map.getTile(tilePos)) {
                    if (!tile->isDrawable())
                        continue;
                    m_cachedVisibleTiles[tilePos.z].push_back(tile);
                    tile->calculateCorpseCorrection();
                }
            }
        }
    }

    m_floorShadowMaskDirty = true;
}

void MapView::buildFloorShadowMask(const Position& cameraPosition)
{
    const int spriteSize = g_sprites.spriteSize();
    const int W = m_drawDimension.width();
    const int H = m_drawDimension.height();
    const int W2 = W * 2;
    const int H2 = H * 2;

    if (!m_floorShadowMaskTexture || m_floorShadowMaskTexture->getSize() != Size(W2, H2)) {
        m_floorShadowMaskTexture = TexturePtr(new Texture(Size(W2, H2), false, true));
        m_floorShadowMaskTexture->setCanCache(false);
    }

    const size_t bufferSize = (size_t)W2 * H2 * 4;
    if (m_floorShadowMaskBuffer.size() < bufferSize)
        m_floorShadowMaskBuffer.resize(bufferSize);
    // default: full shadow intensity everywhere (holes, background, uncovered tiles)
    std::fill(m_floorShadowMaskBuffer.begin(), m_floorShadowMaskBuffer.end(), 255);

    std::vector<uint8_t> cover(W * H, 0);
    std::vector<uint8_t> hole(W * H, 0);

    const int currentFloor = cameraPosition.z;

    // tiles of the current floor with an opaque ground cover the lower floors
    for (const TilePtr& tile : m_cachedVisibleTiles[currentFloor]) {
        const Point p = transformPositionTo2D(tile->getPosition(), cameraPosition);
        const int tx = p.x / spriteSize;
        const int ty = p.y / spriteSize;
        if (tx < 0 || ty < 0 || tx >= W || ty >= H) continue;
        const ItemPtr ground = tile->getGround();
        if (ground && ground->isGround() && !ground->isTranslucent())
            cover[ty * W + tx] = 1;
    }

    // any visible lower floor tile on an uncovered texel is a hole: the exact
    // place where the hard shadow edge used to be
    for (int f = currentFloor + 1; f <= m_cachedLastVisibleFloor; ++f) {
        for (const TilePtr& tile : m_cachedVisibleTiles[f]) {
            const Point p = transformPositionTo2D(tile->getPosition(), cameraPosition);
            const int tx = p.x / spriteSize;
            const int ty = p.y / spriteSize;
            if (tx < 0 || ty < 0 || tx >= W || ty >= H) continue;
            if (!cover[ty * W + tx])
                hole[ty * W + tx] = 1;
        }
    }

    const float fadePx = std::max(1.f, m_floorShadowFadeWidth);
    const int radius = (int)std::ceil(fadePx / (float)spriteSize) + 1;

    // the mask has 2x2 texels per tile so the falloff is sampled at sub-tile
    // resolution and stays smooth after bilinear filtering
    for (int sy = 0; sy < H2; ++sy) {
        const int ty = sy / 2;
        const float cy = sy * 0.5f + 0.25f;
        const int ty0 = std::max(0, ty - radius);
        const int ty1 = std::min(H - 1, ty + radius);
        for (int sx = 0; sx < W2; ++sx) {
            const int tx = sx / 2;
            if (!cover[ty * W + tx])
                continue; // hole / background texels keep full shadow

            const float cx = sx * 0.5f + 0.25f;
            const int tx0 = std::max(0, tx - radius);
            const int tx1 = std::min(W - 1, tx + radius);
            float minDistSq = std::numeric_limits<float>::max();
            for (int hy = ty0; hy <= ty1; ++hy) {
                for (int hx = tx0; hx <= tx1; ++hx) {
                    if (!hole[hy * W + hx]) continue;
                    // distance from the texel center to the hole tile rectangle
                    const float dx = std::max(hx - cx, std::max(0.f, cx - (hx + 1)));
                    const float dy = std::max(hy - cy, std::max(0.f, cy - (hy + 1)));
                    const float d2 = dx * dx + dy * dy;
                    if (d2 < minDistSq) minDistSq = d2;
                }
            }
            const size_t idx = (size_t)(sy * W2 + sx) * 4;
            float alpha = 0.f;
            if (minDistSq < std::numeric_limits<float>::max()) {
                const float distPx = std::sqrt(minDistSq) * spriteSize;
                const float t = stdext::clamp<float>(distPx / fadePx, 0.f, 1.f);
                if (m_floorShadowFadeEasing == 1)
                    alpha = 1.f - t; // linear
                else
                    alpha = 1.f - t * t * (3.f - 2.f * t); // smoothstep
            }
            m_floorShadowMaskBuffer[idx] = 255;
            m_floorShadowMaskBuffer[idx + 1] = 255;
            m_floorShadowMaskBuffer[idx + 2] = 255;
            m_floorShadowMaskBuffer[idx + 3] = (uint8)(stdext::clamp<float>(alpha, 0.f, 1.f) * 255.f);
        }
    }
}

void MapView::updateGeometry(const Size& visibleDimension, const Size& optimizedSize)
{
    m_multifloor = true;
    m_visibleDimension = visibleDimension;
    m_drawDimension = visibleDimension + Size(3, 3);
    m_virtualCenterOffset = (m_drawDimension / 2 - Size(1, 1)).toPoint();
    m_visibleCenterOffset = m_virtualCenterOffset;
    m_optimizedSize = m_drawDimension * g_sprites.spriteSize();
    requestVisibleTilesCacheUpdate();
}

void MapView::onTileUpdate(const Position& pos)
{
    requestVisibleTilesCacheUpdate();
}

void MapView::onMapCenterChange(const Position& pos)
{
    requestVisibleTilesCacheUpdate();
}

void MapView::lockFirstVisibleFloor(int firstVisibleFloor)
{
    m_lockedFirstVisibleFloor = firstVisibleFloor;
    requestVisibleTilesCacheUpdate();
}

void MapView::unlockFirstVisibleFloor()
{
    m_lockedFirstVisibleFloor = -1;
    requestVisibleTilesCacheUpdate();
}

void MapView::setVisibleDimension(const Size& visibleDimension)
{
    //if(visibleDimension == m_visibleDimension)
    //    return;

    if(visibleDimension.width() % 2 != 1 || visibleDimension.height() % 2 != 1) {
        g_logger.traceError("visible dimension must be odd");
        return;
    }

    if(visibleDimension < Size(3,3)) {
        g_logger.traceError("reach max zoom in");
        return;
    }

    updateGeometry(visibleDimension, m_optimizedSize);
}

void MapView::optimizeForSize(const Size& visibleSize)
{
    updateGeometry(m_visibleDimension, visibleSize);
}

void MapView::followCreature(const CreaturePtr& creature)
{
    m_follow = true;
    m_followingCreature = creature;
    m_walkSmoothValid = false; // camera nova: reancora em vez de deslizar
    requestVisibleTilesCacheUpdate();
}

void MapView::setCameraPosition(const Position& pos)
{
    m_follow = false;
    m_customCameraPosition = pos;
    m_walkSmoothValid = false;
    requestVisibleTilesCacheUpdate();
}

Position MapView::getPosition(const Point& point, const Size& mapSize)
{
    Position cameraPosition = getCameraPosition();

    // if we have no camera, its impossible to get the tile
    if(!cameraPosition.isValid())
        return Position();

    Rect srcRect = calcFramebufferSource(mapSize);
    float sh = srcRect.width() / (float)mapSize.width();
    float sv = srcRect.height() / (float)mapSize.height();

    Point framebufferPos = Point(point.x * sh, point.y * sv);
    Point realPos = (framebufferPos + srcRect.topLeft());
    Point centerOffset = realPos / g_sprites.spriteSize();

    Point tilePos2D = getVisibleCenterOffset() - m_drawDimension.toPoint() + centerOffset + Point(2,2);
    if(tilePos2D.x + cameraPosition.x < 0 && tilePos2D.y + cameraPosition.y < 0)
        return Position();

    Position position = Position(tilePos2D.x, tilePos2D.y, 0) + cameraPosition;

    if(!position.isValid())
        return Position();

    return position;
}

Point MapView::getPositionOffset(const Point& point, const Size& mapSize)
{
    Position cameraPosition = getCameraPosition();

    // if we have no camera, its impossible to get the tile
    if (!cameraPosition.isValid())
        return Point(0, 0);

    Rect srcRect = calcFramebufferSource(mapSize);
    float sh = srcRect.width() / (float)mapSize.width();
    float sv = srcRect.height() / (float)mapSize.height();

    Point framebufferPos = Point(point.x * sh, point.y * sv);
    Point realPos = (framebufferPos + srcRect.topLeft());
    return Point(realPos.x % g_sprites.spriteSize(), realPos.y % g_sprites.spriteSize());
}

void MapView::move(int x, int y)
{
    m_moveOffset.x += x;
    m_moveOffset.y += y;

    int32_t tmp = m_moveOffset.x / g_sprites.spriteSize();
    bool requestTilesUpdate = false;
    if(tmp != 0) {
        m_customCameraPosition.x += tmp;
        m_moveOffset.x %= g_sprites.spriteSize();
        requestTilesUpdate = true;
    }

    tmp = m_moveOffset.y / g_sprites.spriteSize();
    if(tmp != 0) {
        m_customCameraPosition.y += tmp;
        m_moveOffset.y %= g_sprites.spriteSize();
        requestTilesUpdate = true;
    }

    if(requestTilesUpdate)
        requestVisibleTilesCacheUpdate();
}

// O alvo da camera e' o tile atual mais o walkOffset: os dois juntos formam uma
// posicao continua em pixels. Aqui a gente filtra a velocidade desse alvo e
// integra, devolvendo so' a parte de dentro do tile, que e' o que o blit do
// framebuffer consome. Com isso a rolagem fica continua mesmo quando o passo
// chega espacado, sem perder o alinhamento no repouso (parado, o valor converge
// exatamente para o walkOffset original) e sem atraso acumulado enquanto anda.
Point MapView::getSmoothedWalkOffset(const Point& walkOffset)
{
    if (m_walkSmoothTime <= 0.0f || !isFollowingCreature())
        return walkOffset;

    const Position cameraPosition = getCameraPosition();
    if (!cameraPosition.isValid())
        return walkOffset;

    const float tileSize = (float)g_sprites.spriteSize();
    const float tileX = cameraPosition.x * tileSize;
    const float tileY = cameraPosition.y * tileSize;
    const float targetX = tileX + walkOffset.x;
    const float targetY = tileY + walkOffset.y;

    const uint32_t now = g_clock.millis();
    if (!m_walkSmoothValid) {
        m_walkSmoothX = targetX;
        m_walkSmoothY = targetY;
        m_walkSmoothTargetX = targetX;
        m_walkSmoothTargetY = targetY;
        m_walkSmoothVelX = 0.0f;
        m_walkSmoothVelY = 0.0f;
        m_walkSmoothValid = true;
        m_walkSmoothTick = now;
        m_walkSmoothOffset = walkOffset;
        return m_walkSmoothOffset;
    }

    // Fundo, frente e hit test do mouse desenham no mesmo frame: todos tem que
    // receber o mesmo offset, senao as camadas desalinham entre si.
    if (now == m_walkSmoothTick)
        return m_walkSmoothOffset;

    float dt = (float)(now - m_walkSmoothTick);
    m_walkSmoothTick = now;
    if (dt <= 0.0f)
        dt = 1.0f;
    else if (dt > 250.0f)
        dt = 250.0f; // pausa longa (alt-tab, loading) nao pode virar deslize enorme

    const float dx = targetX - m_walkSmoothX;
    const float dy = targetY - m_walkSmoothY;
    const float snapDistance = std::max(tileSize * 3.0f, m_walkSmoothMaxLag * 4.0f);

    if (std::fabs(dx) > snapDistance || std::fabs(dy) > snapDistance) {
        // teleporte, troca de andar ou mapa novo: cola direto no alvo
        m_walkSmoothX = targetX;
        m_walkSmoothY = targetY;
        m_walkSmoothTargetX = targetX;
        m_walkSmoothTargetY = targetY;
        m_walkSmoothVelX = 0.0f;
        m_walkSmoothVelY = 0.0f;
    } else {
        // O que o filtro suaviza e' a *velocidade* do alvo, nao a posicao. Em
        // movimento constante a velocidade filtrada e' a propria velocidade, entao
        // a camera acompanha o alvo sem atraso nenhum - e virar de direcao nao
        // precisa desfazer atraso acumulado, que era a travadinha ao trocar de
        // direcao (pior na diagonal, onde o atraso dos dois eixos somava e batia
        // no limite de maxLag). Ja as variacoes bruscas - um SQM de uma vez, ou a
        // inversao ao virar - saem espalhadas no tempo em vez de surgir de uma
        // vez so', que e' o deslize que tira o pulo de SQM em SQM.
        const float rawVelX = (targetX - m_walkSmoothTargetX) / dt;
        const float rawVelY = (targetY - m_walkSmoothTargetY) / dt;
        m_walkSmoothTargetX = targetX;
        m_walkSmoothTargetY = targetY;

        const float alpha = 1.0f - std::exp(-dt / m_walkSmoothTime);
        m_walkSmoothVelX += (rawVelX - m_walkSmoothVelX) * alpha;
        m_walkSmoothVelY += (rawVelY - m_walkSmoothVelY) * alpha;

        m_walkSmoothX += m_walkSmoothVelX * dt;
        m_walkSmoothY += m_walkSmoothVelY * dt;

        // Rede de seguranca bem mais lenta que o deslize: o filtro de velocidade
        // preserva o deslocamento, mas se um passo for interrompido no meio
        // sobraria um resto - aqui ele converge sem encurtar a suavizacao.
        const float driftAlpha = 1.0f - std::exp(-dt / (m_walkSmoothTime * 4.0f));
        m_walkSmoothX += (targetX - m_walkSmoothX) * driftAlpha;
        m_walkSmoothY += (targetY - m_walkSmoothY) * driftAlpha;
    }

    m_walkSmoothOffset = Point((int)std::lround(m_walkSmoothX - tileX),
                               (int)std::lround(m_walkSmoothY - tileY));
    return m_walkSmoothOffset;
}

Rect MapView::calcFramebufferSource(const Size& destSize, bool inNextFrame)
{
    float scaleFactor = g_sprites.spriteSize()/(float)g_sprites.spriteSize();
    Point drawOffset = ((m_drawDimension - m_visibleDimension - Size(1,1)).toPoint()/2) * g_sprites.spriteSize();
    if(isFollowingCreature())
        drawOffset += getSmoothedWalkOffset(m_followingCreature->getWalkOffset(inNextFrame)) * scaleFactor;

    Size srcSize = destSize;
    Size srcVisible = m_visibleDimension * g_sprites.spriteSize();
    srcSize.scale(srcVisible, Fw::KeepAspectRatio);
    drawOffset.x += (srcVisible.width() - srcSize.width()) / 2;
    drawOffset.y += (srcVisible.height() - srcSize.height()) / 2;

    return Rect(drawOffset, srcSize);
}

int MapView::calcFirstVisibleFloor(bool forFading)
{
    int z = 7;
    // return forced first visible floor
    if(m_lockedFirstVisibleFloor != -1) {
        z = m_lockedFirstVisibleFloor;
    } else {
        Position cameraPosition = getCameraPosition();

        // this could happens if the player is not known yet
        if(cameraPosition.isValid()) {
            // avoid rendering multifloors in far views
            if(!m_multifloor) {
                z = cameraPosition.z;
            } else {
                // if nothing is limiting the view, the first visible floor is 0
                int firstFloor = 0;

                // limits to underground floors while under sea level
                if(cameraPosition.z > Otc::SEA_FLOOR)
                    firstFloor = std::max<int>(cameraPosition.z - Otc::AWARE_UNDEGROUND_FLOOR_RANGE, (int)Otc::UNDERGROUND_FLOOR);

                // loop in 3x3 tiles around the camera
                for(int ix = -1; ix <= 1 && firstFloor < cameraPosition.z && !forFading; ++ix) {
                    for(int iy = -1; iy <= 1 && firstFloor < cameraPosition.z; ++iy) {
                        Position pos = cameraPosition.translated(ix, iy);

                        // process tiles that we can look through, e.g. windows, doors
                        if((ix == 0 && iy == 0) || ((std::abs(ix) != std::abs(iy)) && g_map.isLookPossible(pos))) {
                            Position upperPos = pos;
                            Position coveredPos = pos;

                            while(coveredPos.coveredUp() && upperPos.up() && upperPos.z >= firstFloor) {
                                // check tiles physically above
                                TilePtr tile = g_map.getTile(upperPos);
                                if(tile && tile->limitsFloorsView(!g_map.isLookPossible(pos))) {
                                    firstFloor = upperPos.z + 1;
                                    break;
                                }

                                // check tiles geometrically above
                                tile = g_map.getTile(coveredPos);
                                if(tile && tile->limitsFloorsView(g_map.isLookPossible(pos))) {
                                    firstFloor = coveredPos.z + 1;
                                    break;
                                }
                            }
                        }
                    }
                }
                z = firstFloor;
            }
        }
    }

    // just ensure the that the floor is in the valid range
    z = stdext::clamp<int>(z, 0, (int)Otc::MAX_Z);
    return z;
}

int MapView::calcLastVisibleFloor()
{
    if(!m_multifloor)
        return calcFirstVisibleFloor();

    int z = 7;

    Position cameraPosition = getCameraPosition();
    // this could happens if the player is not known yet
    if(cameraPosition.isValid()) {
        // view only underground floors when below sea level
        if(cameraPosition.z > Otc::SEA_FLOOR)
            z = cameraPosition.z + Otc::AWARE_UNDEGROUND_FLOOR_RANGE;
        else
            z = Otc::SEA_FLOOR;
    }

    if(m_lockedFirstVisibleFloor != -1)
        z = std::max<int>(m_lockedFirstVisibleFloor, z);

    // just ensure the that the floor is in the valid range
    z = stdext::clamp<int>(z, 0, (int)Otc::MAX_Z);
    return z;
}

Point MapView::transformPositionTo2D(const Position& position, const Position& relativePosition) {
    return Point((m_virtualCenterOffset.x + (position.x - relativePosition.x) - (relativePosition.z - position.z)) * g_sprites.spriteSize(),
        (m_virtualCenterOffset.y + (position.y - relativePosition.y) - (relativePosition.z - position.z)) * g_sprites.spriteSize());
}


Position MapView::getCameraPosition()
{
    if (isFollowingCreature()) {
        return m_followingCreature->getPrewalkingPosition();
    }

    return m_customCameraPosition;
}

void MapView::setDrawLights(bool enable)
{
    m_drawLight = enable;
}

void MapView::setCrosshair(const std::string& file)     
{
    if (file == "")
        m_crosshair = nullptr;
    else
        m_crosshair = g_textures.getTexture(file);
}

/* vim: set ts=4 sw=4 et: */
