/*
 * NormalMapManager implementation
 */

#include "normalmapmanager.h"
#include "spritemanager.h"
#include <framework/graphics/texturemanager.h>
#include <framework/graphics/texture.h>
#include <framework/graphics/image.h>
#include <framework/core/resourcemanager.h>
#include <framework/graphics/painter.h>

NormalMapManager g_normalMaps;

NormalMapManager::NormalMapManager()
{
    m_enabled = false;
    resetLights();
}

void NormalMapManager::init()
{
    // Normal mapping is disabled by default.  When enabled it overrides
    // every sprite draw with a per-pixel lighting shader that bypasses
    // the atlas cache (cache() returns false) and recalculates lighting
    // each frame, causing visible tile flicker as point-lights shuffle.
    m_enabled = false;
}

void NormalMapManager::terminate()
{
    m_normalMaps.clear();
    m_checked.clear();
    m_defaultNormalMap = nullptr;
}

uint32_t NormalMapManager::makeKey(uint16 clientId, ThingCategory category) const
{
    return (static_cast<uint32_t>(category) << 16) | clientId;
}

ImagePtr NormalMapManager::getNormalMap(uint16 clientId, ThingCategory category)
{
    if (!m_enabled || clientId == 0)
        return nullptr;

    uint32_t key = makeKey(clientId, category);

    // Check cache first
    auto it = m_normalMaps.find(key);
    if (it != m_normalMaps.end()) {
        return it->second; // may be nullptr if we already checked and found nothing
    }

    // Check if we already tried loading this one
    auto checkedIt = m_checked.find(key);
    if (checkedIt != m_checked.end()) {
        return nullptr; // already checked, no normal map
    }

    // Try to load
    m_checked[key] = true;
    ImagePtr normalMap = loadNormalMap(clientId, category);
    m_normalMaps[key] = normalMap;
    return normalMap;
}

bool NormalMapManager::hasNormalMap(uint16 clientId, ThingCategory category)
{
    return getNormalMap(clientId, category) != nullptr;
}

ImagePtr NormalMapManager::loadNormalMap(uint16 clientId, ThingCategory category)
{
    // Convention: data/normalmaps/{category}/{clientId}_n.png
    std::string categoryStr;
    switch (category) {
        case ThingCategoryItem:     categoryStr = "item"; break;
        case ThingCategoryCreature: categoryStr = "creature"; break;
        case ThingCategoryEffect:   categoryStr = "effect"; break;
        case ThingCategoryMissile:  categoryStr = "missile"; break;
        default: return nullptr;
    }

    std::string path = stdext::format("data/normalmaps/%s/%d_n.png", categoryStr, clientId);

    // Try to resolve and load the file
    try {
        ImagePtr image = Image::load(path);
        if (image) {
            g_logger.debug(stdext::format("NormalMapManager: loaded normal map for %s %d", categoryStr, clientId));
            return image;
        }
    } catch (...) {
        // File doesn't exist, that's fine
    }

    return nullptr;
}

ImagePtr NormalMapManager::getDefaultNormalMap()
{
    if (!m_defaultNormalMap) {
        // Create a 1x1 neutral normal map image: (128, 128, 255) = (0, 0, 1) in tangent space
        uchar pixels[4] = { 128, 128, 255, 255 };
        m_defaultNormalMap = ImagePtr(new Image(Size(1, 1), 4, pixels));
    }
    return m_defaultNormalMap;
}

void NormalMapManager::resetLights()
{
    m_lightData.lightCount = 0;
    for (int i = 0; i < MAX_NORMAL_MAP_LIGHTS; ++i) {
        m_lightData.lights[i] = NormalMapLight();
    }
    m_lightData.ambientLight = 0.3f;
    m_lightData.sunDirX = 0.8f;
    m_lightData.sunDirY = -0.6f;
    m_lightData.sunDirZ = 0.5f;
    m_lightData.sunIntensity = 1.0f;
}

void NormalMapManager::addLight(float posX, float posY, float radius, float intensity, float r, float g, float b)
{
    if (m_lightData.lightCount >= MAX_NORMAL_MAP_LIGHTS)
        return;

    NormalMapLight& light = m_lightData.lights[m_lightData.lightCount++];
    light.posX = posX;
    light.posY = posY;
    light.radius = radius;
    light.intensity = intensity;
    light.colorR = r;
    light.colorG = g;
    light.colorB = b;
}

void NormalMapManager::setSunLight(float dirX, float dirY, float dirZ, float intensity)
{
    m_lightData.sunDirX = dirX;
    m_lightData.sunDirY = dirY;
    m_lightData.sunDirZ = dirZ;
    m_lightData.sunIntensity = intensity;
}
