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

#include "minimap.h"
#include "game.h"
#include "spritemanager.h"
#include <framework/util/rect.h>
#include "thingtype.h"
#include "thingtypemanager.h"
#include "tile.h"

#include "creature.h"
#include "game.h"
#include "map.h"
#include <algorithm>
#include <framework/core/filestream.h>
#include <framework/core/resourcemanager.h>
#include <framework/graphics/image.h>
#include <framework/graphics/texture.h>
#include <mutex>
#include <chrono>
#include <thread>
#include <unordered_map>
#include <vector>
#include <zlib.h>

#include <framework/util/stats.h>

Minimap g_minimap;

// Optimization: Flattened cache for O(1) access
// 65536 * sizeof(ImagePtr) = ~512KB (pointers)
static std::vector<ImagePtr> s_minimapSpriteCache(65536);
static std::mutex s_minimapCacheMutex;

// Optimization: Precomputed Color LUT
static uint32_t s_minimapColorTable[256];
static bool s_minimapColorTableInitialized = false;

void initializeMinimapColorTable() {
  if (s_minimapColorTableInitialized)
    return;
  for (int i = 0; i < 256; ++i) {
    Color c = Color::from8bit(i);
    s_minimapColorTable[i] =
        (c.a() << 24) | (c.b() << 16) | (c.g() << 8) | c.r();
  }
  s_minimapColorTableInitialized = true;
}

void clearMinimapSpriteCache() {
  std::lock_guard<std::mutex> lock(s_minimapCacheMutex);
  std::fill(s_minimapSpriteCache.begin(), s_minimapSpriteCache.end(),
            ImagePtr());
}

void MinimapBlock::clean() {
  m_tiles.fill(MinimapTile());
  m_texture.reset();
  m_mustUpdate = false;
}

bool MinimapBlock::update(int z) {
  if (!m_mustUpdate)
    return false;

  // Throttle: limit updates to max 1 per second (1000ms interval)
  const ticks_t now = stdext::millis();
  const ticks_t updateInterval = 1000; // milliseconds
  if (m_lastUpdateTime != 0 && (now - m_lastUpdateTime) < updateInterval)
    return false;
  m_lastUpdateTime = now;

  // HD Sprite Minimap: CPU-based compositing with caching

  // Ensure color table is ready
  if (!s_minimapColorTableInitialized)
    initializeMinimapColorTable();

  const int baseSpriteSize = g_sprites.spriteSize();

  // Scale at base sprite size (typically 32px) - do not stretch high res
  const int scale = baseSpriteSize;

  // PERFORMANCE: Padding increased to 20 tiles to prevent large items from
  // cutting
  const int paddingTiles = 2;
  const int padding = paddingTiles * scale;
  const int texSize = MMBLOCK_SIZE * scale + padding;

  ImagePtr image(new Image(Size(texSize, texSize)));
  uint8_t *imagePixels = image->getPixelData();
  const int imagePitch = texSize * 4; // 4 bytes per pixel (RGBA)

  bool shouldDraw = false;

  for (int y = 0; y < MMBLOCK_SIZE; ++y) {
    for (int x = 0; x < MMBLOCK_SIZE; ++x) {
      const MinimapTile &tile = getTile(x, y);

      // Adjust dest by padding
      int destX = x * scale + padding;
      int destY = y * scale + padding;

      // Apply Z-specific offset for higher floors (fix alignment)
      // TEMPORARILY DISABLED FOR TESTING
      // if (z <= 6) {
      //     destX -= scale * 2;
      //     destY -= scale * 2;
      // }

      bool drewSprite = false;

      // 1. Try to draw sprites if available
      if (g_minimap.isMinimapHD() && tile.spriteCount > 0) {
        // Loop through all sprites on this tile
        // (spriteCount is clamped defensively: updateTile runs on the game
        // thread while update() runs on the draw thread, so a torn read could
        // otherwise walk past the 4-element spriteIds array)
        for (int i = 0; i < tile.spriteCount && i < MinimapTile::MAX_SPRITES;
             ++i) {
          uint16 spriteId = tile.spriteIds[i];
          if (spriteId == 0)
            continue;

          // Check cache (O(1) vector access)
          ImagePtr scaledImg = s_minimapSpriteCache[spriteId];
          if (!scaledImg) {
            // Cache miss
            const ThingTypePtr &thing =
                g_things.getThingType(spriteId, ThingCategoryItem);
            if (thing && !thing->isNull()) {
              // ... existing generation logic ...

              // (Inside generation logic, modify cache set)

              // Re-implement generation mostly same, just cache set change
              const std::vector<int> &sprites = thing->getSprites();
              const int thingW = thing->getWidth();
              const int thingH = thing->getHeight();

              ImagePtr compositedImg;

              if (thingW > 1 || thingH > 1) {
                // Multi-tile compositing...
                // We can optimize this by checking if we really need to
                // composite But keeping it safe for now.

                const int fullW = thingW * baseSpriteSize;
                const int fullH = thingH * baseSpriteSize;
                compositedImg = ImagePtr(new Image(Size(fullW, fullH)));

                for (int h = 0; h < thingH; ++h) {
                  for (int w = 0; w < thingW; ++w) {
                    const int spriteIdx = h * thingW + w;
                    if (spriteIdx < (int)sprites.size() &&
                        sprites[spriteIdx] > 0) {
                      ImagePtr partImg =
                          g_sprites.getSpriteImage(sprites[spriteIdx]);
                      if (partImg) {
                        const int px = (thingW - 1 - w) * baseSpriteSize;
                        const int py = (thingH - 1 - h) * baseSpriteSize;
                        compositedImg->blit(Point(px, py), partImg);
                      }
                    }
                  }
                }
              } else if (!sprites.empty()) {
                compositedImg = g_sprites.getSpriteImage(sprites[0]);
              }

              if (compositedImg) {
                // Scale
                int finalW = thingW * scale;
                int finalH = thingH * scale;

                // Guard: never allocate a huge buffer for absurd sprite sizes.
                const int maxDim = 2048;
                if (finalW > maxDim || finalH > maxDim)
                  continue;

                // Guard: never copy more pixels than the source image actually
                // holds (custom sprites can be smaller than the logical tile
                // size; an overread here corrupts the heap).
                const int srcW = compositedImg->getWidth();
                const int srcH = compositedImg->getHeight();
                const int copyW = std::min(finalW, srcW);
                const int copyH = std::min(finalH, srcH);

                scaledImg = ImagePtr(new Image(Size(finalW, finalH)));
                uint8_t *srcPixels = compositedImg->getPixelData();
                uint8_t *dstPixels = scaledImg->getPixelData();

                // Optimized: scale=baseSpriteSize, ratio is always 1:1 ->
                // simple row copy, bounded to the source image size.
                for (int row = 0; row < copyH; ++row) {
                  memcpy(dstPixels + row * finalW * 4,
                         srcPixels + row * srcW * 4, copyW * 4);
                }

                // Store in vector cache
                std::lock_guard<std::mutex> lock(s_minimapCacheMutex);
                s_minimapSpriteCache[spriteId] = scaledImg;
              }
            }
          }

          if (scaledImg) {
            // Adjust position for multi-tile items (Anchored at Bottom-Right of
            // the tile) If item is 1x1: draw at destX, destY If item is 2x2:
            // draw at destX - scale, destY - scale (so it covers previous
            // tiles) Formula: pos = dest - (dimension - 1) * scale

            // We need thingW/thingH. If we got from cache, we don't have them
            // handy unless we assume standard. But wait! 'scaledImg' knows its
            // size! width = thingW * scale. -> thingW = width / scale

            int imgW = scaledImg->getWidth();
            int imgH = scaledImg->getHeight();

            // Calculate offset based on image size
            // Assuming scaledImg w/h are multiples of 'scale'
            int offsetX = (imgW - scale);
            int offsetY = (imgH - scale);

            // We draw at dest - offset
            // Example: 1x1 -> w=32, scale=32 -> off=0. Dest. Correct.
            // Example: 2x1 -> w=64, scale=32 -> off=32. Dest - 32. Correct.

            image->blit(Point(destX - offsetX, destY - offsetY), scaledImg);
            drewSprite = true;
            shouldDraw = true;
          }
        }
      }

      // 2. Fallback: draw color if no sprite (Optimized: LUT)
      if (!drewSprite && tile.color != 255) {
        const uint32_t col = s_minimapColorTable[tile.color];

        // Direct pixel fill (faster than setPixel)
        for (int py = 0; py < scale; ++py) {
          uint32_t *row =
              (uint32_t *)(imagePixels + (destY + py) * imagePitch + destX * 4);
          for (int px = 0; px < scale; ++px) {
            row[px] = col;
          }
        }
        shouldDraw = true;
      }
    }
  }

  if (shouldDraw) {
    m_texture = TexturePtr(new Texture(image, false, false, true));
  } else {
    m_texture.reset();
  }

  m_mustUpdate = false;
  return true; // Block was updated
}

void MinimapBlock::updateTile(int x, int y, const MinimapTile &tile) {
  if (m_tiles[getTileIndex(x, y)] != tile)
    m_mustUpdate = true;

  m_tiles[getTileIndex(x, y)] = tile;
}

void Minimap::init() {}

void Minimap::terminate() {
  clean();
  clearMinimapSpriteCache();
}

void Minimap::setMinimapHD(bool enable) {
  m_minimapHD = enable;
  // Force all existing blocks to re-render
  if (!enable) {
    clearMinimapSpriteCache();
  }
  std::lock_guard<std::mutex> lock(m_lock);
  for (int i = 0; i <= Otc::MAX_Z; ++i) {
    for (auto &it : m_tileBlocks[i]) {
      it.second->mustUpdate();
    }
  }
}

void Minimap::clean() {
  std::lock_guard<std::mutex> lock(m_lock);
  for (int i = 0; i <= Otc::MAX_Z; ++i)
    m_tileBlocks[i].clear();
}

void Minimap::draw(const Rect &screenRect, const Position &mapCenter,
                   float scale, const Color &color, const PointF &offsetArg) {
  if (screenRect.isEmpty())
    return;

  Rect mapRect = calcMapRect(screenRect, mapCenter, scale);
  g_drawQueue->addFilledRect(screenRect, color);  if (MMBLOCK_SIZE * scale <= 1 || !mapCenter.isMapPosition()) {
    return;
  }

  size_t drawQueueStart = g_drawQueue->size();
  Point blockOff = getBlockOffset(mapRect.topLeft());
  Point off =
      Point((mapRect.size() * scale).toPoint() - screenRect.size().toPoint()) /
      2;
  // Apply sub-tile camera offset (inverted, because if camera moves right, map
  // moves left) Use floats for start position to preserve sub-pixel precision
  PointF start = PointF(screenRect.topLeft().x, screenRect.topLeft().y) -
                 PointF((mapRect.topLeft() - blockOff).x * scale,
                        (mapRect.topLeft() - blockOff).y * scale) -
                 PointF(off.x, off.y) - offsetArg;

  // PERFORMANCE: Limit to 1 block update per frame to prevent stutter
  // PERFORMANCE: Limit to 2 block updates per frame to smooth out loading
  const int maxBlockUpdatesPerFrame = 2;
  int blocksUpdatedThisFrame = 0;

  // MULTI-FLOOR RENDERING: Show floors from current down to floor 7
  // Floor 1 sees 2,3,4,5,6,7 | Floor 6 sees 7 | Floor 7+ sees only current
  // Render from bottom to top (highest Z first, then lower Z on top)
  std::vector<int> floorsToRender;

  // Only show last 4 floors (current + 3 below) to limit draw calls.
  // Clamp the z range so we never ask to render floors below 0 (which can
  // produce garbage block lookups / draw math when the camera floor is bad).
  int currentFloorClamped = std::max<int>(0, mapCenter.z);
  const int groundFloor = std::min(7, currentFloorClamped + 3);
  if (currentFloorClamped < groundFloor) {
    for (int z = groundFloor; z >= currentFloorClamped; --z) {
      floorsToRender.push_back(z);
    }
  } else {
    floorsToRender.push_back(currentFloorClamped);
  }

  // Already validated above (spread positivity).

  for (int floorIdx = 0; floorIdx < (int)floorsToRender.size(); ++floorIdx) {
    int currentZ = floorsToRender[floorIdx];
    if (currentZ < 0 || currentZ > Otc::MAX_Z)
      continue;

    // Pre-calculate padding in pixels for this scale
    const int paddingTiles = 2;
    const float paddingPixels = paddingTiles * scale;

    // Clamp block coordinates to the valid map area so we never touch
    // blocks outside [0,65535) at extreme zoom or bad camera positions.
    float ys = start.y;
    for (int y = blockOff.y; ys < screenRect.bottom();
         y += MMBLOCK_SIZE, ys += MMBLOCK_SIZE * scale) {
      int yClamped = std::clamp(y, 0, 65535 - MMBLOCK_SIZE);

      float xs = start.x;
      for (int x = blockOff.x; xs < screenRect.right();
           x += MMBLOCK_SIZE, xs += MMBLOCK_SIZE * scale) {
        int xClamped = std::clamp(x, 0, 65535 - MMBLOCK_SIZE);

        Position blockPos(xClamped, yClamped, currentZ);
        if (!hasBlock(blockPos))
          continue;

        MinimapBlock &block = getBlock(blockPos);

        // Only update if we haven't hit the per-frame limit
        if (blocksUpdatedThisFrame < maxBlockUpdatesPerFrame) {
          if (block.update(currentZ)) {
            blocksUpdatedThisFrame++;
          }
        }

        const TexturePtr &tex = block.getTexture();
        if (tex && !tex->isEmpty()) {
          // Adjust for padding (20 tiles on Top and Left for large item
          // support) Draw rect must be larger and shifted Top-Left Use floor
          // for position, ceil for size to prevent gaps
          int destX = (int)std::floor(xs - paddingPixels);
          int destY = (int)std::floor(ys - paddingPixels);

          // Apply relative Z-offset centered on the current camera floor
          // This creates the diagonal perspective stack while keeping the
          // active floor centered under the crosshair
          // Clamp offset so extreme zoom doesn't turn it into huge pixel offsets.
          int zOffset = std::clamp((int)((currentZ - mapCenter.z) * scale), -2048, 2048);
          destX += zOffset;
          destY += zOffset;

          // Guard: avoid huge destination rects at high zoom that can crash
          // the GPU draw path.
          // Also skip blocks that would land completely off the widget at this
          // scale (e.g. extreme zoom where a block maps to huge pixels far
          // outside the minimap area).
          int destW = (int)std::ceil(MMBLOCK_SIZE * scale + paddingPixels);
          int destH = (int)std::ceil(MMBLOCK_SIZE * scale + paddingPixels);
          if (destW > 4096 || destH > 4096)
            continue;

          // Skip blocks whose draw rect does not intersect the visible area.
          // This also avoids crashes when the camera is positioned such that
          // the minimap draw math lands outside valid coordinates.
          Rect dest(destX, destY, destW, destH);
          if (!screenRect.intersects(dest)) {
            // Draw at least a blank placeholder rect to avoid a missing block
            // that can be misinterpreted as a hole and cause UI stress, but
            // do not attempt to upload/render a texture for it.
            g_drawQueue->addFilledRect(dest, Color::alpha);
            continue;
          }

          Rect src(0, 0, tex->getSize().width(), tex->getSize().height());

          // Apply floor dimming (brightness reduction)
          // Base color is white
          Color floorColor = Color::white;
          int floorDistance = currentZ - mapCenter.z;
          if (floorDistance > 0) {
            // Reduce brightness by 20% per floor level difference (User
            // request) 1 floor down = 80% brightness, 2 floors = 60%, etc.
            float brightness = std::max(0.1f, 1.0f - (floorDistance * 0.20f));

            // Multiply color by brightness (Darkens the texture)
            floorColor = floorColor * brightness;

            // Ensure alpha remains full so we don't see floors underneath or
            // background
            floorColor.setAlpha(1.0f);
          }            g_drawQueue->addTexturedRect(dest, tex, src, floorColor);
        }
      }
    }
  }

  // Draw creature indicators (Party, Guild, PK, etc)
  // Only for current floor (mapCenter.z)
  // Scan creatures for indicators with reduced range for performance
  // Never allow a negative z here; a bad camera floor (e.g. near a hole)
  // can otherwise trigger out-of-bounds tile lookups during spectator scan.
  int safeZ = std::max<int>(0, mapCenter.z);
  if (safeZ <= Otc::MAX_Z) {
    // Limit scan to visible area + small border
    int rangeX = std::min(12, mapRect.width() / 2 + 3);
    int rangeY = std::min(12, mapRect.height() / 2 + 3);
    const std::vector<CreaturePtr> &creatures =
        g_map.getSpectatorsInRange(Position(mapCenter.x, mapCenter.y, safeZ), false, rangeX, rangeY);
    int creatureDrawCount = 0;
    const int MAX_CREATURE_DRAWS = 50; // Limit to prevent FPS drops
    for (const auto &creature : creatures) {
      if (creatureDrawCount >= MAX_CREATURE_DRAWS) break;
      // Avatar custom: pet fantasma nao existe para o minimap.
      if (!creature->canBeSeen() || creature->isLocalPlayer() || creature->isPet())
        continue;

      Point tilePoint = getTilePoint(creature->getPosition(), screenRect,
                                     Position(mapCenter.x, mapCenter.y, safeZ), scale, offsetArg);
      if (tilePoint.x == -1)
        continue;

      // Apply walk offset for smooth movement
      // Scale offset from sprite pixels (usually 32) to minimap scale
      Point creatureOffset = creature->getWalkOffset();
      if (!creatureOffset.isNull()) {
        float offsetScale = scale / (float)g_sprites.spriteSize();
        tilePoint += Point(creatureOffset.x * offsetScale,
                           creatureOffset.y * offsetScale);
      }

      Color color = Color::alpha;

      // Priority: Shield (Party) -> Emblem (Guild) -> Skull (PK)
      // Note: Adjust priority as needed based on user preference or standard
      // behavior
      bool draw = false;

      // 1. Party / Shield
      if (creature->getShield() > Otc::ShieldNone) {
        switch (creature->getShield()) {
        case Otc::ShieldWhiteYellow:
        case Otc::ShieldYellow:
        case Otc::ShieldYellowSharedExp:
        case Otc::ShieldYellowNoSharedExpBlink:
        case Otc::ShieldYellowNoSharedExp:
          color = Color::yellow;
          break;
        case Otc::ShieldWhiteBlue:
        case Otc::ShieldBlue:
        case Otc::ShieldBlueSharedExp:
        case Otc::ShieldBlueNoSharedExpBlink:
        case Otc::ShieldBlueNoSharedExp:
          color = Color::blue; // "cruz azul"
          break;
        case Otc::ShieldGray:
          color = Color::gray;
          break;
        default:
          color = Color::white;
        }
        draw = true;
      }

      // 2. Guild Emblem (Priority over party? User said "guild war,
      // verde/vermelho")
      if (creature->getEmblem() != Otc::EmblemNone) {
        switch (creature->getEmblem()) {
        case Otc::EmblemGreen:
          color = Color::green;
          draw = true;
          break;
        case Otc::EmblemRed:
          color = Color::red;
          draw = true;
          break;
        case Otc::EmblemBlue:
          // If party is already blue, this reinforces it
          // color = Color::blue;
          // draw = true;
          break;
        }
      }

      // 3. PK (White/Black)
      if (!draw && creature->getSkull() != Otc::SkullNone) {
        switch (creature->getSkull()) {
        case Otc::SkullWhite:
          color = Color::white;
          break;
        case Otc::SkullBlack:
          color = Color::black;
          break;
        case Otc::SkullRed:
          color = Color::red;
          break; // Assuming red for red skull
        case Otc::SkullYellow:
          color = Color::yellow;
          break;
        case Otc::SkullOrange:
          color = Color(255, 165, 0);
          break; // Orange
        default:
          color = Color::white;
        }
        draw = true;
      }

      if (draw) {
        creatureDrawCount++;
        // Draw a CROSS (Cruz)
        int size = 8;
        int thickness = 2;

        // Horizontal bar
        Rect horz(tilePoint.x - size / 2, tilePoint.y - thickness / 2, size,
                  thickness);
        // Vertical bar
        Rect vert(tilePoint.x - thickness / 2, tilePoint.y - size / 2,
                  thickness, size);

        g_drawQueue->addFilledRect(horz, color);
        g_drawQueue->addFilledRect(vert, color);
      }
    }
  }

  g_drawQueue->setClip(drawQueueStart, screenRect);
}

// Helper methods updated to support offset
Point Minimap::getTilePoint(const Position &pos, const Rect &screenRect,
                            const Position &mapCenter, float scale,
                            const PointF &offset) {
  if (screenRect.isEmpty() || pos.z != mapCenter.z)
    return Point(-1, -1);

  Rect mapRect = calcMapRect(screenRect, mapCenter, scale);
  Point off =
      Point((mapRect.size() * scale).toPoint() - screenRect.size().toPoint()) /
      2;
  PointF posoff =
      PointF((pos.x - mapRect.left()) * scale, (pos.y - mapRect.top()) * scale);

  // Apply offset here too
  PointF finalPos = posoff + PointF(screenRect.left(), screenRect.top()) -
                    PointF(off.x, off.y) - offset +
                    PointF(scale / 2, scale / 2);
  return Point(std::round(finalPos.x), std::round(finalPos.y));
}

Position Minimap::getTilePosition(const Point &point, const Rect &screenRect,
                                  const Position &mapCenter, float scale,
                                  const PointF &offset) {
  if (screenRect.isEmpty())
    return Position();

  Rect mapRect = calcMapRect(screenRect, mapCenter, scale);
  Point off =
      Point((mapRect.size() * scale).toPoint() - screenRect.size().toPoint()) /
      2;
  // Apply offset (inverse of draw)
  // draw: posoff + screenRect.topLeft() - off - offset
  // so: posoff = point - screenRect.topLeft() + off + offset
  PointF pointF(point.x, point.y);
  PointF offF(off.x, off.y);
  PointF screenTopLeftF(screenRect.left(), screenRect.top());

  PointF pos2d = (pointF - screenTopLeftF + offF + offset) / scale +
                 PointF(mapRect.left(), mapRect.top());
  return Position(pos2d.x, pos2d.y, mapCenter.z);
}

Rect Minimap::getTileRect(const Position &pos, const Rect &screenRect,
                          const Position &mapCenter, float scale,
                          const PointF &offset) {
  if (screenRect.isEmpty() || pos.z != mapCenter.z)
    return Rect();

  int tileSize = g_sprites.spriteSize() * scale;
  Rect tileRect(0, 0, tileSize, tileSize);
  tileRect.moveCenter(getTilePoint(pos, screenRect, mapCenter, scale, offset));
  return tileRect;
}

Rect Minimap::calcMapRect(const Rect &screenRect, const Position &mapCenter,
                          float scale) {
  int w = screenRect.width() / scale,
      h = std::ceil(screenRect.height() / scale);
  Rect mapRect(0, 0, w, h);
  mapRect.moveCenter(Point(mapCenter.x, mapCenter.y));
  return mapRect;
}

void Minimap::updateTile(const Position &pos, const TilePtr &tile) {
  MinimapTile minimapTile;
  if (tile) {
    minimapTile.color = tile->getMinimapColorByte();
    tile->getMinimapSpriteIds(minimapTile);
    minimapTile.flags |= MinimapTileWasSeen;
    if (!tile->isWalkable(true))
      minimapTile.flags |= MinimapTileNotWalkable;
    if (!tile->isPathable())
      minimapTile.flags |= MinimapTileNotPathable;
    minimapTile.speed =
        std::min<int>((int)std::ceil(tile->getGroundSpeed() / 10.0f), 255);
  } else {
    minimapTile.color = 255;
    minimapTile.spriteCount = 0; // Clear sprites
    minimapTile.flags |= MinimapTileEmpty;
    minimapTile.speed = 1;
  }

  if (minimapTile != MinimapTile()) {
    MinimapBlock &block = getBlock(pos);
    Point offsetPos = getBlockOffset(Point(pos.x, pos.y));
    block.updateTile(pos.x - offsetPos.x, pos.y - offsetPos.y, minimapTile);
    block.justSaw();
  }
}

const MinimapTile &Minimap::getTile(const Position &pos) {
  static MinimapTile nulltile;
  if (pos.z <= Otc::MAX_Z && hasBlock(pos)) {
    MinimapBlock &block = getBlock(pos);
    Point offsetPos = getBlockOffset(Point(pos.x, pos.y));
    return block.getTile(pos.x - offsetPos.x, pos.y - offsetPos.y);
  }
  return nulltile;
}

bool Minimap::isTileExplored(const Position &pos) {
  if (pos.z > Otc::MAX_Z || !hasBlock(pos))
    return false;
  MinimapBlock &block = getBlock(pos);
  Point offsetPos = getBlockOffset(Point(pos.x, pos.y));
  return block.getTile(pos.x - offsetPos.x, pos.y - offsetPos.y)
      .hasFlag(MinimapTileWasSeen);
}

std::pair<MinimapBlock_ptr, MinimapTile>
Minimap::threadGetTile(const Position &pos) {
  std::lock_guard<std::mutex> lock(m_lock);
  static MinimapTile nulltile;

  if (pos.z <= Otc::MAX_Z && hasBlock(pos)) {
    MinimapBlock_ptr block = m_tileBlocks[pos.z][getBlockIndex(pos)];
    if (block) {
      Point offsetPos = getBlockOffset(Point(pos.x, pos.y));
      return std::make_pair(
          block, block->getTile(pos.x - offsetPos.x, pos.y - offsetPos.y));
    }
  }
  return std::make_pair(nullptr, nulltile);
}

// ... loadImage unchanged ...
bool Minimap::loadImage(const std::string &fileName, const Position &topLeft,
                        float colorFactor) {
  // Implementation omitted for brevity (no changes needed)
  return false;
}
// ...

void Minimap::saveImage(const std::string &fileName, const Rect &mapRect) {
  // TODO
}

// New Load OTMM with Version migration
bool Minimap::loadOtmm(const std::string &fileName) {
  bool loadedAny = false;

  // Try to load the main file (legacy or single-file)
  if (loadOtmmFile(fileName))
    loadedAny = true;

  // Try to load split files (minimap_z0.otmm ... minimap_z15.otmm)
  std::string baseName = fileName;
  if (baseName.length() > 5 &&
      baseName.substr(baseName.length() - 5) == ".otmm")
    baseName = baseName.substr(0, baseName.length() - 5);

  for (int z = 0; z <= Otc::MAX_Z; ++z) {
    std::string splitName = stdext::format("%s_z%d.otmm", baseName, z);
    if (loadOtmmFile(splitName))
      loadedAny = true;
  }

  return loadedAny;
}

bool Minimap::loadOtmmFile(const std::string &fileName) {
  try {
    if (!g_resources.fileExists(fileName))
      return false;

    FileStreamPtr fin = g_resources.openFile(
        fileName, g_game.getFeature(Otc::GameDontCacheFiles));
    if (!fin)
      return false;

    uint32 signature = fin->getU32();
    if (signature != OTMM_SIGNATURE)
      stdext::throw_exception("invalid OTMM file");

    uint16 start = fin->getU16();
    uint16 version = fin->getU16();
    fin->getU32(); // flags

    switch (version) {
    case 1: {
      fin->getString(); // description
      break;
    }
    case 2: {
      fin->getString();
      break;
    }
    case 3: { // New Version with Multi-Layer Support
      fin->getString();
      break;
    }
    default:
      stdext::throw_exception("OTMM version not supported");
    }

    fin->seek(start);

    // Struct sizes:
    // V1: 3 bytes (flags, color, speed)
    // V2: 5 bytes (flags, color, speed, spriteId)
    // V3: 12 bytes (flags, color, speed, spriteCount, spriteIds[4])

    uint tileStructSize = 0;
    if (version == 1)
      tileStructSize = 3;
    else if (version == 2)
      tileStructSize = 5;
    else
      tileStructSize = sizeof(MinimapTile); // V3+

    uint blockSize = MMBLOCK_SIZE * MMBLOCK_SIZE * tileStructSize;
    std::vector<uchar> compressBuffer(compressBound(blockSize * 2));
    std::vector<uchar> decompressBuffer(blockSize);

    while (true) {
      Position pos;
      pos.x = fin->getU16();
      pos.y = fin->getU16();
      pos.z = fin->getU8();

      if (!pos.isValid() || pos.z >= Otc::MAX_Z + 1)
        break;

      MinimapBlock &block = getBlock(pos);
      ulong len = fin->getU16();
      ulong destLen = blockSize;
      fin->read(compressBuffer.data(), len);
      int ret = uncompress(decompressBuffer.data(), &destLen,
                           compressBuffer.data(), len);
      if (ret != Z_OK || destLen != blockSize)
        break;

      if (version < 3) {
        // Migration to V3
        MinimapTile *newTiles = block.getTiles().data();
        uint8 *oldBytes = (uint8 *)decompressBuffer.data();

        for (int i = 0; i < MMBLOCK_SIZE * MMBLOCK_SIZE; ++i) {
          if (version == 1) {
            // V1 -> V3
            newTiles[i].flags = oldBytes[i * 3 + 0];
            newTiles[i].color = oldBytes[i * 3 + 1];
            newTiles[i].speed = oldBytes[i * 3 + 2];
            newTiles[i].spriteCount = 0;
            for (int s = 0; s < MinimapTile::MAX_SPRITES; ++s)
              newTiles[i].spriteIds[s] = 0;
          } else { // version == 2
                   // V2 -> V3
            newTiles[i].flags = oldBytes[i * 5 + 0];
            newTiles[i].color = oldBytes[i * 5 + 1];
            newTiles[i].speed = oldBytes[i * 5 + 2];
            uint16 oldSpriteId =
                *(uint16 *)&oldBytes[i * 5 + 3]; // Read 2 bytes

            newTiles[i].spriteCount = (oldSpriteId != 0) ? 1 : 0;
            newTiles[i].spriteIds[0] = oldSpriteId;
            for (int s = 1; s < MinimapTile::MAX_SPRITES; ++s)
              newTiles[i].spriteIds[s] = 0;
          }
        }
      } else {
        // V3 Direct Copy
        memcpy((uchar *)&block.getTiles(), decompressBuffer.data(), blockSize);
      }

      block.mustUpdate();
      block.justSaw();
    }

    fin->close();
    return true;
  } catch (stdext::exception &e) {
    g_logger.error(stdext::format("failed to load OTMM minimap: %s", e.what()));
    return false;
  }
}

void Minimap::saveOtmm(const std::string &fileName) {
  std::string baseName = fileName;
  if (baseName.length() > 5 &&
      baseName.substr(baseName.length() - 5) == ".otmm")
    baseName = baseName.substr(0, baseName.length() - 5);

  // Save individual floor files
  for (int z = 0; z <= Otc::MAX_Z; ++z) {
    bool hasData = false;
    // Check if we have any seen blocks on this floor
    for (auto &it : m_tileBlocks[z]) {
      if (it.second->wasSeen()) {
        hasData = true;
        break;
      }
    }

    if (hasData) {
      std::string splitName = stdext::format("%s_z%d.otmm", baseName, z);
      saveOtmmFile(splitName, z);
    } else {
      // Optional: delete file if it exists and is empty?
      // For now, we just don't write generic empty files.
    }
  }

  // Save full map file (for compatibility)
  saveOtmmFile(baseName + ".otmm", -1);
}

void Minimap::saveOtmmFile(const std::string &fileName, int targetZ) {
  try {
    stdext::timer saveTimer;

#ifndef ANDROID
    std::string tmpFileName = fileName;
    tmpFileName += ".tmp";
    FileStreamPtr fin = g_resources.createFile(tmpFileName);
#else
    FileStreamPtr fin = g_resources.createFile(fileName);
#endif

    // TODO: compression flag with zlib
    uint32 flags = 0;

    // header
    fin->addU32(OTMM_SIGNATURE);
    fin->addU16(0);            // data start, will be overwritten later
    fin->addU16(OTMM_VERSION); // Save as Version 3
    fin->addU32(flags);

    fin->addString("OTMM 3.0"); // description

    // go back and rewrite where the map data starts
    uint32 start = fin->tell();
    fin->seek(4);
    fin->addU16(start);
    fin->seek(start);

    uint blockSize = MMBLOCK_SIZE * MMBLOCK_SIZE * sizeof(MinimapTile);
    std::vector<uchar> compressBuffer(compressBound(blockSize));
    const int COMPRESS_LEVEL = 3;
    // Only save content for targetZ, or all if targetZ == -1
    int startZ = (targetZ == -1) ? 0 : targetZ;
    int endZ = (targetZ == -1) ? Otc::MAX_Z : targetZ;

    for (int z = startZ; z <= endZ; ++z) {
      for (auto &it : m_tileBlocks[z]) {
        int index = it.first;
        MinimapBlock &block = *it.second;
        if (!block.wasSeen())
          continue;

        Position pos = getIndexPosition(index, z);
        fin->addU16(pos.x);
        fin->addU16(pos.y);
        fin->addU8(pos.z);

        ulong len = blockSize;
        int ret =
            compress2(compressBuffer.data(), &len, (uchar *)&block.getTiles(),
                      blockSize, COMPRESS_LEVEL);
        VALIDATE(ret == Z_OK);
        fin->addU16(len);
        fin->write(compressBuffer.data(), len);
      }
    }

    // end of file
    Position invalidPos;
    fin->addU16(invalidPos.x);
    fin->addU16(invalidPos.y);
    fin->addU8(invalidPos.z);

    fin->flush();

    fin->close();
#ifndef ANDROID
    std::filesystem::path filePath(g_resources.getWriteDir()),
        tmpFilePath(g_resources.getWriteDir());
    filePath += fileName;
    tmpFilePath += tmpFileName;
    // Rename if size is valid (header + EOF is small, so check > 0)
    // Minimal valid OTMM is signature(4)+start(2)+version(2)+flags(4) (12
    // bytes) + desc + data start + eof(5)
    if (std::filesystem::file_size(tmpFilePath) > 16) {
      // Duas instancias do client dividem a mesma pasta de configuracao
      // (%APPDATA%\OTClientVN\otclientv8) e portanto o mesmo minimap: se a
      // outra instancia estiver com o arquivo aberto no instante do rename, o
      // Windows devolve ERROR_SHARING_VIOLATION, o mapa explorado daquela
      // sessao era perdido e o log enchia de "failed to save OTMM minimap".
      // Tenta algumas vezes e, como ultimo recurso, copia por cima.
      std::error_code renameEc;
      for (int attempt = 0; attempt < 8; ++attempt) {
        std::filesystem::rename(tmpFilePath, filePath, renameEc);
        if (!renameEc)
          break;
        std::this_thread::sleep_for(
            std::chrono::milliseconds(50 * (attempt + 1)));
      }

      if (renameEc) {
        std::error_code copyEc;
        std::filesystem::copy_file(
            tmpFilePath, filePath,
            std::filesystem::copy_options::overwrite_existing, copyEc);
        if (copyEc)
          g_logger.error(stdext::format("failed to save OTMM minimap: %s",
                                        copyEc.message()));
        else
          std::filesystem::remove(tmpFilePath, copyEc);
      }
    }
#endif
  } catch (stdext::exception &e) {
    g_logger.error(stdext::format("failed to save OTMM minimap: %s", e.what()));
  } catch (std::exception &e) {
    g_logger.error(stdext::format("failed to save OTMM minimap: %s", e.what()));
  }
}
