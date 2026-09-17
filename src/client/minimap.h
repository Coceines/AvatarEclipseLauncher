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

#ifndef MINIMAP_H
#define MINIMAP_H

#include "declarations.h"
#include <framework/graphics/declarations.h>

enum { MMBLOCK_SIZE = 64, OTMM_SIGNATURE = 0x4D4d544F, OTMM_VERSION = 3 };

enum MinimapTileFlags {
  MinimapTileWasSeen = 1,
  MinimapTileNotPathable = 2,
  MinimapTileNotWalkable = 4,
  MinimapTileEmpty = 8
};

#pragma pack(push, 1) // disable memory alignment
struct MinimapTile {
  static const int MAX_SPRITES = 4; // Ground + up to 3 items
  MinimapTile() : flags(0), color(255), speed(10), spriteCount(0) {
    for (int i = 0; i < MAX_SPRITES; ++i)
      spriteIds[i] = 0;
  }
  uint8 flags;
  uint8 color;
  uint8 speed;
  uint8 spriteCount;
  uint16 spriteIds[MAX_SPRITES]; // Multiple sprites per tile
  bool hasFlag(MinimapTileFlags flag) const { return flags & flag; }
  int getSpeed() const { return speed * 10; }
  bool operator==(const MinimapTile &other) const {
    if (color != other.color || flags != other.flags || speed != other.speed ||
        spriteCount != other.spriteCount)
      return false;
    for (int i = 0; i < spriteCount; ++i)
      if (spriteIds[i] != other.spriteIds[i])
        return false;
    return true;
  }
  bool operator!=(const MinimapTile &other) const { return !(*this == other); }
};

class MinimapBlock {
public:
  void clean();
  bool update(int z); // Returns true if actually updated
  void updateTile(int x, int y, const MinimapTile &tile);
  MinimapTile &getTile(int x, int y) { return m_tiles[getTileIndex(x, y)]; }
  void resetTile(int x, int y) { m_tiles[getTileIndex(x, y)] = MinimapTile(); }
  uint getTileIndex(int x, int y) {
    return ((y % MMBLOCK_SIZE) * MMBLOCK_SIZE) + (x % MMBLOCK_SIZE);
  }
  const TexturePtr &getTexture() { return m_texture; }
  std::array<MinimapTile, MMBLOCK_SIZE * MMBLOCK_SIZE> &getTiles() {
    return m_tiles;
  }
  void mustUpdate() { m_mustUpdate = true; }
  void justSaw() { m_wasSeen = true; }
  bool wasSeen() { return m_wasSeen; }

private:
  TexturePtr m_texture;
  std::array<MinimapTile, MMBLOCK_SIZE * MMBLOCK_SIZE> m_tiles;
  stdext::boolean<true> m_mustUpdate;
  stdext::boolean<false> m_wasSeen;
  ticks_t m_lastUpdateTime = 0; // For update throttling
};

#pragma pack(pop)

using MinimapBlock_ptr = std::shared_ptr<MinimapBlock>;

class Minimap {

public:
  void init();
  void terminate();

  void clean();

  void draw(const Rect &screenRect, const Position &mapCenter, float scale,
            const Color &color, const PointF &offset = PointF(0, 0));
  Point getTilePoint(const Position &pos, const Rect &screenRect,
                     const Position &mapCenter, float scale,
                     const PointF &offset = PointF(0, 0));
  Position getTilePosition(const Point &point, const Rect &screenRect,
                           const Position &mapCenter, float scale,
                           const PointF &offset = PointF(0, 0));
  Rect getTileRect(const Position &pos, const Rect &screenRect,
                   const Position &mapCenter, float scale,
                   const PointF &offset = PointF(0, 0));

  void setMinimapHD(bool enable);
  bool isMinimapHD() { return m_minimapHD; }

  void updateTile(const Position &pos, const TilePtr &tile);
  const MinimapTile &getTile(const Position &pos);
  // true se o tile ja foi visto/desbloqueado no minimapa (tem flag WasSeen)
  bool isTileExplored(const Position &pos);
  std::pair<MinimapBlock_ptr, MinimapTile> threadGetTile(const Position &pos);

  bool loadImage(const std::string &fileName, const Position &topLeft,
                 float colorFactor);
  void saveImage(const std::string &fileName, const Rect &mapRect);
  bool loadOtmm(const std::string &fileName);
  void saveOtmm(const std::string &fileName);

private:
  bool loadOtmmFile(const std::string &fileName);
  void saveOtmmFile(const std::string &fileName, int z);
  Rect calcMapRect(const Rect &screenRect, const Position &mapCenter,
                   float scale);
  bool hasBlock(const Position &pos) {
    return m_tileBlocks[pos.z].find(getBlockIndex(pos)) !=
           m_tileBlocks[pos.z].end();
  }
  MinimapBlock &getBlock(const Position &pos) {
    std::lock_guard<std::mutex> lock(m_lock);
    auto &ptr = m_tileBlocks[pos.z][getBlockIndex(pos)];
    if (!ptr)
      ptr = std::make_shared<MinimapBlock>();
    return *ptr;
  }
  Point getBlockOffset(const Point &pos) {
    return Point(pos.x - pos.x % MMBLOCK_SIZE, pos.y - pos.y % MMBLOCK_SIZE);
  }
  Position getIndexPosition(int index, int z) {
    return Position((index % (65536 / MMBLOCK_SIZE)) * MMBLOCK_SIZE,
                    (index / (65536 / MMBLOCK_SIZE)) * MMBLOCK_SIZE, z);
  }
  uint getBlockIndex(const Position &pos) {
    return ((pos.y / MMBLOCK_SIZE) * (65536 / MMBLOCK_SIZE)) +
           (pos.x / MMBLOCK_SIZE);
  }
  std::unordered_map<uint, MinimapBlock_ptr> m_tileBlocks[Otc::MAX_Z + 1];
  std::mutex m_lock;
  bool m_minimapHD = true;
};

extern Minimap g_minimap;

#endif
