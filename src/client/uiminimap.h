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

#ifndef UIMINIMAP_H
#define UIMINIMAP_H

#include "declarations.h"
#include <framework/ui/uiwidget.h>

class UIMinimap : public UIWidget {
public:
  UIMinimap();

  void drawSelf(Fw::DrawPane drawPane);
  void draw(const Rect &visibleRect, Fw::DrawPane drawPane) override;

  // When a shader is set the whole widget (map, cross and marks) is rendered
  // into an offscreen buffer and then drawn back through it, so the shader sees
  // the map as one single image instead of a pile of separate tiles.
  void setShader(const std::string &shader) { m_shader = shader; }
  std::string getShader() { return m_shader; }
  // Strength of the lens effect applied by the shader, needed to keep mouse
  // clicks aligned with what is drawn on screen.
  void setLensStrength(float strength);
  float getLensStrength() { return m_lensStrength; }

  bool zoomIn() { return m_zoom < m_maxZoom ? setZoom(m_zoom + 1) : false; }
  bool zoomOut() { return m_zoom > m_minZoom ? setZoom(m_zoom - 1) : false; }

  void setSecondaryView(bool secondary) { m_secondaryView = secondary; }
  bool isSecondaryView() { return m_secondaryView; }
  void setSecondaryOffset(float dx, float dy) { m_secondaryOffsetX = dx; m_secondaryOffsetY = dy; }

  bool setZoom(int zoom);
  void setMinZoom(int minZoom) { m_minZoom = minZoom; }
  void setMaxZoom(int maxZoom) { m_maxZoom = maxZoom; }
  void setCameraPosition(const Position &pos);
  bool floorUp();
  bool floorDown();

  Point getTilePoint(const Position &pos);
  Rect getTileRect(const Position &pos);
  Position getTilePosition(const Point &mousePos);

  Position getCameraPosition() { return m_cameraPosition; }
  int getMinZoom() { return m_minZoom; }
  int getMaxZoom() { return m_maxZoom; }
  int getZoom() { return m_zoom; }
  float getScale() { return m_scale; }

  void anchorPosition(const UIWidgetPtr &anchoredWidget,
                      Fw::AnchorEdge anchoredEdge,
                      const Position &hookedPosition,
                      Fw::AnchorEdge hookedEdge);
  void fillPosition(const UIWidgetPtr &anchoredWidget,
                    const Position &hookedPosition);
  void centerInPosition(const UIWidgetPtr &anchoredWidget,
                        const Position &hookedPosition);

protected:
  virtual void onZoomChange(int zoom, int oldZoom);
  virtual void onCameraPositionChange(const Position &position,
                                      const Position &oldPosition);
  PointF calculateSmoothOffset(const Position &targetPos = Position());
  virtual void onStyleApply(const std::string &styleName,
                            const OTMLNodePtr &styleNode) override;

private:
  void update();
  Point lensAdjustPoint(const Point &point);

  Rect m_mapArea;
  Position m_cameraPosition;
  Position m_targetCameraPosition; // For smooth camera
  float m_visualCameraX;           // Float position for smooth rendering
  float m_visualCameraY;
  float m_smoothFactor; // Camera smoothing speed (0.0 = instant, 1.0 = slowest)
  float m_scale;
  int m_zoom;
  int m_minZoom;
  int m_maxZoom;
  bool m_secondaryView = false;
  float m_secondaryOffsetX = 0.0f;
  float m_secondaryOffsetY = 0.0f;
  std::string m_shader;
  float m_lensStrength = 0.0f;
};

#endif
