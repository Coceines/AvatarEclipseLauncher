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

#ifndef LIGHTVIEW_H
#define LIGHTVIEW_H

#include "declarations.h"
#include "thingtype.h"
#include <framework/graphics/declarations.h>
#include <framework/graphics/drawqueue.h>
#include "normalmapmanager.h"
#include "spritemanager.h"
#include <set>

struct TileLight {
    size_t start;
    uint8_t color;
};

class LightView : public DrawQueueItem
{
public:
    LightView(TexturePtr& lightTexture, const Size& mapSize, const Rect& dest, const Rect& src, uint8_t color, uint8_t intensity, const std::vector<bool>& blockingMap) :
        DrawQueueItem(nullptr), m_lightTexture(lightTexture), m_mapSize(mapSize), m_dest(dest), m_src(src), m_blockingMap(blockingMap), m_lightSeed(0, 0) {
        m_globalLight = Color::from8bit(color) * ((float)intensity / 255.f);
        m_tiles.resize(m_mapSize.area(), TileLight{ 0, 0 });
    }

    inline void addLight(const Point& pos, const Light& light)
    {
        // Also feed the normal map system
        if (g_normalMaps.isEnabled() && light.intensity > 0) {
            Color lc = Color::from8bit(light.color);
            g_normalMaps.addLight(pos.x, pos.y,
                                  light.intensity * g_sprites.spriteSize() * 0.3f,
                                  light.intensity / 255.0f,
                                  lc.rF(), lc.gF(), lc.bF());
        }
        return addLight(pos, light.color, light.intensity);
    }
    void addLight(const Point& pos, uint8_t color, uint8_t intensity);
    // Camera offset in pixels, added to every light's screen position before
    // hashing its breathing phase, so the pulse is tied to the light's world
    // position instead of its (moving) screen position.
    void setLightSeed(const Point& seed) { m_lightSeed = seed; }
    void setFieldBrightness(const Point& pos, size_t start, uint8_t color);
    size_t size() { return m_lights.size(); }

    void draw() override;

private:
    bool isBlocked(float x0, float y0, float x1, float y1, int spriteSize) const;

    TexturePtr m_lightTexture;
    Size m_mapSize;
    Rect m_dest, m_src;
    Color m_globalLight;
    std::vector<Light> m_lights;
    std::vector<TileLight> m_tiles;
    std::vector<bool> m_blockingMap;
    Point m_lightSeed;
};

#endif

