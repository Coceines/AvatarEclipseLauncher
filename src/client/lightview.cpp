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

#include "lightview.h"
#include "spritemanager.h"
#include <framework/graphics/painter.h>
#include <framework/core/clock.h>
#include <framework/stdext/math.h>
#include <algorithm>
#include <cmath>

// Ray march from light to pixel: returns true if a wall blocks the path.
// Uses Bresenham-style tile stepping at the lightmap (half-res) grid.
bool LightView::isBlocked(float x0, float y0, float x1, float y1, int spriteSize) const
{
    // Convert pixel coords to tile coords
    int tx0 = (int)(x0 / spriteSize);
    int ty0 = (int)(y0 / spriteSize);
    int tx1 = (int)(x1 / spriteSize);
    int ty1 = (int)(y1 / spriteSize);

    int dx = std::abs(tx1 - tx0);
    int dy = std::abs(ty1 - ty0);
    int sx = tx0 < tx1 ? 1 : -1;
    int sy = ty0 < ty1 ? 1 : -1;
    int err = dx - dy;

    int fullW = m_mapSize.width();
    int fullH = m_mapSize.height();

    while (true) {
        // Skip the tile where the light source itself sits
        if (tx0 != tx1 || ty0 != ty1) {
            if (tx0 >= 0 && tx0 < fullW && ty0 >= 0 && ty0 < fullH) {
                if (m_blockingMap[ty0 * fullW + tx0])
                    return true;
            }
        }

        if (tx0 == tx1 && ty0 == ty1) break;

        int e2 = 2 * err;
        if (e2 > -dy) { err -= dy; tx0 += sx; }
        if (e2 < dx)  { err += dx; ty0 += sy; }
    }
    return false;
}

void LightView::addLight(const Point& pos, uint8_t color, uint8_t intensity)
{
    if (!m_lights.empty()) {
        Light& prevLight = m_lights.back();
        if (prevLight.pos == pos && prevLight.color == color) {
            prevLight.intensity = std::max(prevLight.intensity, intensity);
            return;
        }
    }
    m_lights.push_back(Light{ pos, color, intensity });
}

void LightView::setFieldBrightness(const Point& pos, size_t start, uint8_t color)
{
    size_t index = (pos.y / g_sprites.spriteSize()) * m_mapSize.width() + (pos.x / g_sprites.spriteSize());
    if (index >= m_tiles.size()) return;
    m_tiles[index].start = start;
    m_tiles[index].color = color;
}

// Smooth exponential falloff — looks like a soft glow, not a hard circle
static inline float softGlow(float distance, float radius)
{
    if (distance >= radius) return 0.f;
    float t = 1.0f - (distance / radius);
    return t * t * t; // cubic ease-out: very soft edge
}

// Breathing pulse: each light gets a unique phase so they don't all sync up.
// The phase is hashed from the light's WORLD position (screen position plus
// the camera seed), which is constant while the camera moves — hashing the
// raw screen position would re-roll the phase on every step and make the
// whole screen flicker. Very subtle (±5%) at ~0.45 Hz.
static inline float breathe(int wx, int wy, float time)
{
    unsigned int ux = (unsigned int)wx;
    unsigned int uy = (unsigned int)wy;
    float phase = (float)((ux * 7919u + uy * 6271u) % 6283u) * 0.001f; // 0..2π
    float wave = std::sin(time * 2.8f + phase); // ~0.45 Hz, slow and calm
    return 1.0f + wave * 0.05f; // ±5% intensity
}

void LightView::draw() // render thread
{
    const int spriteSize = g_sprites.spriteSize();
    const int fullW = m_mapSize.width();
    const int fullH = m_mapSize.height();
    const int area = fullW * fullH;

    static std::vector<uint8_t> buffer;
    if (buffer.size() < static_cast<size_t>(area) * 4)
        buffer.resize(static_cast<size_t>(area) * 4);

    // Time for the breathing animation
    const float time = (float)g_clock.millis() * 0.001f;

    // Visible region in TILE units. m_src is in pixels and the light texture
    // has exactly one texel per tile, so UV = pixels / spriteSize.
    const float srcTileX = (float)m_src.left() / spriteSize;
    const float srcTileY = (float)m_src.top() / spriteSize;
    const float srcTileW = std::max(1.0f, (float)m_src.width() / spriteSize);
    const float srcTileH = std::max(1.0f, (float)m_src.height() / spriteSize);

    // Vignette center (middle of the visible region)
    const float centerX = (srcTileX + srcTileW * 0.5f) * spriteSize;
    const float centerY = (srcTileY + srcTileH * 0.5f) * spriteSize;
    const float maxDist = std::sqrt((srcTileW * spriteSize * 0.5f) * (srcTileW * spriteSize * 0.5f) +
                                    (srcTileH * spriteSize * 0.5f) * (srcTileH * spriteSize * 0.5f));

    for (int x = 0; x < fullW; ++x) {
        for (int y = 0; y < fullH; ++y) {
            const float cx = x * spriteSize + spriteSize * 0.5f;
            const float cy = y * spriteSize + spriteSize * 0.5f;

            const int colorIndex = (y * fullW + x) * 4;

            // ---- Base darkness (world light) ----
            float baseR = m_globalLight.rF();
            float baseG = m_globalLight.gF();
            float baseB = m_globalLight.bF();

            // Soft radial vignette for depth
            if (maxDist > 0.0f) {
                const float ddx = cx - centerX;
                const float ddy = cy - centerY;
                const float distCenter = std::sqrt(ddx * ddx + ddy * ddy) / maxDist;
                const float vignette = 1.0f - stdext::clamp(distCenter, 0.0f, 1.0f) * 0.18f;
                baseR *= vignette;
                baseG *= vignette;
                baseB *= vignette;
            }

            // ---- Accumulate every light (always at full strength) ----
            float lightAddR = 0.0f, lightAddG = 0.0f, lightAddB = 0.0f;

            {
                for (size_t i = 0; i < m_lights.size(); ++i) {
                    const Light& light = m_lights[i];
                    const float dx = cx - light.pos.x;
                    const float dy = cy - light.pos.y;
                    const float distance = std::sqrt(dx * dx + dy * dy) / spriteSize;

                    // Breathing pulse: world-locked phase, so it keeps the same
                    // rhythm no matter how far the light is from the camera.
                    const float pulse = breathe(light.pos.x + m_lightSeed.x,
                                                light.pos.y + m_lightSeed.y, time);

                    // Generous radius with smooth cubic falloff
                    const float radius = light.intensity * 1.1f * pulse;
                    const float intensity = softGlow(distance, radius) * pulse;

                    if (intensity < 0.004f)
                        continue;

                    // Walls block light (ray march from the pixel to the source)
                    if (isBlocked(cx, cy, light.pos.x, light.pos.y, spriteSize))
                        continue;

                    const Color lightColor = Color::from8bit(light.color);
                    // Warm tint: a touch more red/green, slightly less blue
                    lightAddR += lightColor.rF() * 1.05f * intensity;
                    lightAddG += lightColor.gF() * 1.02f * intensity;
                    lightAddB += lightColor.bF() * 0.95f * intensity;
                }
            }

            // ---- Blend: per-channel so warm lights never crush blue/green ----
            // Each channel recedes from ambient proportionally to the light it
            // actually receives — this eliminates the dark outline that a global
            // keepDark factor creates when lightAddR >> lightAddB.
            const float lr = std::min(1.0f, lightAddR);
            const float lg = std::min(1.0f, lightAddG);
            const float lb = std::min(1.0f, lightAddB);

            buffer[colorIndex]     = (uint8_t)stdext::clamp((baseR * (1.0f - lr) + lr) * 255.0f, 0.0f, 255.0f);
            buffer[colorIndex + 1] = (uint8_t)stdext::clamp((baseG * (1.0f - lg) + lg) * 255.0f, 0.0f, 255.0f);
            buffer[colorIndex + 2] = (uint8_t)stdext::clamp((baseB * (1.0f - lb) + lb) * 255.0f, 0.0f, 255.0f);
            buffer[colorIndex + 3] = 200; // slightly transparent for a clean result
        }
    }

    // Upload the full lightmap (1 texel per tile). GL_LINEAR upscaling is what
    // produces the soft, continuous blur when it is stretched over the screen.
    glActiveTexture(GL_TEXTURE7);
    m_lightTexture->update();
    glBindTexture(GL_TEXTURE_2D, m_lightTexture->getId());
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fullW, fullH, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, buffer.data());
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glActiveTexture(GL_TEXTURE0);

    // Draw the lightmap over the scene, using the exact same source rect the
    // tiles were rendered with so the glow stays aligned with its tile.
    CoordsBuffer coords;
    coords.addRect(
        RectF(m_dest.left(), m_dest.top(), m_dest.width(), m_dest.height()),
        RectF(srcTileX, srcTileY, srcTileW, srcTileH));

    g_painter->resetColor();
    g_painter->resetTexture();
    g_painter->setCompositionMode(Painter::CompositionMode_Multiply);
    g_painter->drawTextureCoords(coords, m_lightTexture);
    g_painter->resetCompositionMode();
}
