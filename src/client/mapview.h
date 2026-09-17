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

#ifndef MAPVIEW_H
#define MAPVIEW_H

#include "declarations.h"
#include <framework/graphics/paintershaderprogram.h>
#include <framework/graphics/declarations.h>
#include <framework/luaengine/luaobject.h>
#include <framework/core/declarations.h>
#include "lightview.h"
#include <vector>

// Draws the floor shadow as a soft gradient mask that follows the shape of the
// borders between the current floor and the visible lower floors, instead of a
// hard full-screen cut. The mask texture has 2x2 texels per tile and is bilinearly
// filtered, so the falloff is smooth and configurable.
class FloorShadowView : public DrawQueueItem
{
public:
    FloorShadowView(const TexturePtr& texture, const Size& mapSize, const Rect& dest, const Rect& src, const Color& color, const std::vector<uint8_t>& buffer) :
        DrawQueueItem(nullptr), m_texture(texture), m_mapSize(mapSize), m_dest(dest), m_src(src), m_color(color), m_buffer(buffer) {}

    void draw() override;

private:
    TexturePtr m_texture;
    Size m_mapSize;
    Rect m_dest, m_src;
    Color m_color;
    std::vector<uint8_t> m_buffer;
};

// @bindclass
class MapView : public LuaObject
{
public:
    MapView();
    ~MapView();
    void drawMapBackground(const Rect& rect, const TilePtr& crosshairTile = nullptr);
    void drawMapForeground(const Rect& rect);

private:
    void drawFloor(short floor, const Position& cameraPosition, const TilePtr& crosshairTile = nullptr);
    void drawTileTexts(const Rect& rect, const Rect& srcRect);
    void drawTileWidget(const Rect& rect, const Rect& srcRect);
    void updateGeometry(const Size& visibleDimension, const Size& optimizedSize);
    void updateVisibleTilesCache();
    void requestVisibleTilesCacheUpdate() { m_mustUpdateVisibleTilesCache = true; }
    void buildFloorShadowMask(const Position& cameraPosition);
protected:
    void onTileUpdate(const Position& pos);
    void onMapCenterChange(const Position& pos);

    friend class Map;

public:
    // floor visibility related
    void lockFirstVisibleFloor(int firstVisibleFloor);
    void unlockFirstVisibleFloor();
    int getLockedFirstVisibleFloor() { return m_lockedFirstVisibleFloor; }

    void setMultifloor(bool enable) { m_multifloor = enable; requestVisibleTilesCacheUpdate(); }
    bool isMultifloor() { return m_multifloor; }

    // map dimension related
    void setVisibleDimension(const Size& visibleDimension);
    void optimizeForSize(const Size & visibleSize);
    Size getVisibleDimension() { return m_visibleDimension; }
    Point getVisibleCenterOffset() { return m_visibleCenterOffset; }
    int getCachedFirstVisibleFloor() { return m_cachedFirstVisibleFloor; }
    int getCachedLastVisibleFloor() { return m_cachedLastVisibleFloor; }

    // camera related
    void followCreature(const CreaturePtr& creature);
    CreaturePtr getFollowingCreature() { return m_followingCreature; }
    bool isFollowingCreature() { return m_followingCreature && m_follow; }

    void setCameraPosition(const Position& pos);
    Position getCameraPosition();

    // Rolagem suave: em vez de colar no alvo (tile + walkOffset) a cada frame, a
    // camera filtra a *velocidade* do alvo e integra. Em movimento constante ela
    // acompanha o alvo sem atraso nenhum - por isso virar de direcao nao trava -
    // mas cada variacao brusca (um SQM de uma vez) vira um deslize.
    // time == 0 desliga. maxLag e' a distancia em que a camera desiste de deslizar
    // e cola no alvo (teleporte, troca de andar, mapa novo).
    void setWalkSmoothingTime(float ms) { m_walkSmoothTime = std::max(0.0f, ms); }
    float getWalkSmoothingTime() { return m_walkSmoothTime; }
    void setWalkSmoothingMaxLag(float px) { m_walkSmoothMaxLag = std::max(0.0f, px); }
    float getWalkSmoothingMaxLag() { return m_walkSmoothMaxLag; }

    void setMinimumAmbientLight(float intensity) { m_minimumAmbientLight = intensity; }
    float getMinimumAmbientLight() { return m_minimumAmbientLight; }

    // drawing related
    void setDrawFlags(Otc::DrawFlags drawFlags) { m_drawFlags = drawFlags; requestVisibleTilesCacheUpdate(); }
    Otc::DrawFlags getDrawFlags() { return m_drawFlags; }

    void setDrawTexts(bool enable) { m_drawTexts = enable; }
    bool isDrawingTexts() { return m_drawTexts; }

    void setDrawNames(bool enable) { m_drawNames = enable; }
    bool isDrawingNames() { return m_drawNames; }

    void setDrawHealthBars(bool enable) { m_drawHealthBars = enable; }
    bool isDrawingHealthBars() { return m_drawHealthBars; }

    void setDrawHealthBarsOnTop(bool enable) { m_drawHealthBarsOnTop = enable; }
    bool isDrawingHealthBarsOnTop() { return m_drawHealthBarsOnTop; }

    void setDrawLights(bool enable);
    bool isDrawingLights() { return m_drawLight; }

    void setDrawManaBar(bool enable) { m_drawManaBar = enable; }
    bool isDrawingManaBar() { return m_drawManaBar; }

    void setDrawPlayerBars(bool enable) { m_drawPlayerBars = enable; }

    void move(int x, int y);

    void setAnimated(bool animated) { m_animated = animated; requestVisibleTilesCacheUpdate(); }
    bool isAnimating() { return m_animated; }

    void setFloorFading(int value) { m_floorFading = value; }
    void setCrosshair(const std::string& file);

    // floor shadow fade related
    void setFloorShadowFadeWidth(float width) { m_floorShadowFadeWidth = std::max(0.f, width); }
    float getFloorShadowFadeWidth() { return m_floorShadowFadeWidth; }
    void setFloorShadowFadeEasing(int easing) { m_floorShadowFadeEasing = easing; }
    int getFloorShadowFadeEasing() { return m_floorShadowFadeEasing; }

    // floor transparency (upper floors near player become semi-transparent)
    void setFloorTransparencyEnabled(bool enable) { m_floorTransparencyEnabled = enable; }
    bool isFloorTransparencyEnabled() { return m_floorTransparencyEnabled; }
    void setFloorTransparency(float opacity) { m_floorTransparency = stdext::clamp<float>(opacity, 0.f, 1.f); }
    float getFloorTransparency() { return m_floorTransparency; }
    void setFloorTransparencyRadius(float radius) { m_floorTransparencyRadius = std::max(0.5f, radius); }
    float getFloorTransparencyRadius() { return m_floorTransparencyRadius; }
    void setFloorTransparencyThreshold(float threshold) { m_floorTransparencyThreshold = stdext::clamp<float>(threshold, 0.0f, 1.0f); }
    float getFloorTransparencyThreshold() { return m_floorTransparencyThreshold; }

    //void setShader(const PainterShaderProgramPtr& shader, float fadein, float fadeout);
    //PainterShaderProgramPtr getShader() { return m_shader; }

    Position getPosition(const Point& point, const Size& mapSize);

    Point getPositionOffset(const Point& point, const Size& mapSize);

    MapViewPtr asMapView() { return static_self_cast<MapView>(); }

private:
    Rect calcFramebufferSource(const Size& destSize, bool inNextFrame = false);
    Point getSmoothedWalkOffset(const Point& walkOffset);
    int calcFirstVisibleFloor(bool forFading = false);
    int calcLastVisibleFloor();
    Point transformPositionTo2D(const Position& position, const Position& relativePosition);

    stdext::timer m_mapRenderTimer;

    int m_lockedFirstVisibleFloor;
    int m_cachedFirstVisibleFloor;
    int m_cachedFirstFadingFloor;
    int m_cachedLastVisibleFloor;
    int m_updateTilesPos;
    int m_floorFading = 500;
    TexturePtr m_crosshair = nullptr;
    Size m_drawDimension;
    Size m_visibleDimension;
    Size m_optimizedSize;
    Point m_virtualCenterOffset;
    Point m_visibleCenterOffset;
    Point m_moveOffset;
    Position m_customCameraPosition;
    Position m_lastCameraPosition;

    // estado da rolagem suave (ver getSmoothedWalkOffset)
    float m_walkSmoothTime = 100.0f;  // ms: constante de tempo do filtro (0 = desligado)
    float m_walkSmoothMaxLag = 16.0f; // px: a partir daqui cola no alvo em vez de deslizar
    float m_walkSmoothX = 0.0f;
    float m_walkSmoothY = 0.0f;
    float m_walkSmoothTargetX = 0.0f; // alvo do frame anterior (base do calculo da velocidade)
    float m_walkSmoothTargetY = 0.0f;
    float m_walkSmoothVelX = 0.0f;    // px/ms: velocidade filtrada do alvo
    float m_walkSmoothVelY = 0.0f;
    bool m_walkSmoothValid = false;

    uint32_t m_walkSmoothTick = 0;
    Point m_walkSmoothOffset;
    stdext::boolean<true> m_mustUpdateVisibleTilesCache;
    stdext::boolean<true> m_multifloor;
    stdext::boolean<true> m_animated;
    stdext::boolean<true> m_drawTexts;
    stdext::boolean<true> m_drawNames;
    stdext::boolean<true> m_drawHealthBars;
    stdext::boolean<false> m_drawHealthBarsOnTop;
    stdext::boolean<true> m_drawManaBar;
    bool m_drawPlayerBars = true;
    stdext::boolean<true> m_smooth;

    bool m_floorShadowMaskDirty = true;
    float m_floorShadowFadeWidth = 32.0f;
    int m_floorShadowFadeEasing = 0; // 0 = smoothstep, 1 = linear
    TexturePtr m_floorShadowMaskTexture;
    std::vector<uint8_t> m_floorShadowMaskBuffer;

    // floor transparency settings
    bool m_floorTransparencyEnabled = true;
    float m_floorTransparency = 0.30f; // opacity of upper-floor tiles near player (0=invisible, 1=opaque)
    float m_floorTransparencyRadius = 2.0f; // radius in SQMs around player box
    float m_floorTransparencyThreshold = 0.30f; // min overlap % of player sprite for same-floor occluders (0..1)

    stdext::timer m_fadingFloorTimers[Otc::MAX_Z + 1];

    stdext::boolean<true> m_follow;
    std::vector<TilePtr> m_cachedVisibleTiles[Otc::MAX_Z + 1];
    CreaturePtr m_followingCreature;
    Otc::DrawFlags m_drawFlags;
    Color m_floorShadow = Color(0.0f, 0.0f, 0.0f, 0.5f);
    bool m_drawLight = false;
    float m_minimumAmbientLight;
    std::unique_ptr<LightView> m_lightView;
    TexturePtr m_lightTexture;

    // Smooth light transitions (lerp)
    Color m_smoothLightColor;
    float m_smoothLightIntensity = 255.f;
    Color m_targetLightColor;
    float m_targetLightIntensity = 255.f;


};

#endif
