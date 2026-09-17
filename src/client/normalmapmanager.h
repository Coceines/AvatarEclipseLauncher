/*
 * NormalMapManager - Manages normal map textures for 2D normal mapping.
 *
 * Normal maps are loaded from data/normalmaps/ directory.
 * Convention: {clientId}_n.png for items, {clientId}_n.png for creatures.
 * Each ThingType can optionally have an associated normal map texture.
 *
 * If no normal map exists for a sprite, the system falls back to a flat
 * normal (0, 0, 1) in the shader, so all existing sprites continue to work.
 */

#ifndef NORMALMAPMANAGER_H
#define NORMALMAPMANAGER_H

#include "declarations.h"
#include "thingtype.h"
#include <framework/graphics/declarations.h>
#include <framework/core/declarations.h>
#include <unordered_map>

// Maximum number of dynamic point lights for normal mapping shader
static constexpr int MAX_NORMAL_MAP_LIGHTS = 8;

struct NormalMapLight {
    float posX = 0.0f;
    float posY = 0.0f;
    float radius = 0.0f;
    float intensity = 0.0f;
    float colorR = 1.0f;
    float colorG = 1.0f;
    float colorB = 1.0f;
    float _pad = 0.0f; // align to 16 bytes
};

struct NormalMapLightData {
    NormalMapLight lights[MAX_NORMAL_MAP_LIGHTS];
    int lightCount = 0;
    float ambientLight = 0.45f;
    float sunDirX = 0.5f;
    float sunDirY = 0.3f;
    float sunDirZ = 1.0f;
    float sunIntensity = 0.6f;
    float _pad1 = 0.0f;
    float _pad2 = 0.0f;
};

// @bindsingleton g_normalMaps
class NormalMapManager
{
public:
    NormalMapManager();
    ~NormalMapManager() = default;

    void init();
    void terminate();

    // Get normal map image for a thing type.
    // Returns nullptr if no normal map exists (graceful fallback).
    ImagePtr getNormalMap(uint16 clientId, ThingCategory category);

    // Check if a normal map exists for a given thing type
    bool hasNormalMap(uint16 clientId, ThingCategory category);

    // Get the default neutral normal map image (1x1, 128/128/255)
    ImagePtr getDefaultNormalMap();

    // Get the global light data for the current frame
    NormalMapLightData& getLightData() { return m_lightData; }
    const NormalMapLightData& getLightData() const { return m_lightData; }

    // Reset light data for new frame
    void resetLights();

    // Add a point light for normal mapping
    void addLight(float posX, float posY, float radius, float intensity, float r, float g, float b);

    // Set directional sun light
    void setSunLight(float dirX, float dirY, float dirZ, float intensity);

    // Set ambient light level (0.0 - 1.0)
    void setAmbientLight(float ambient) { m_lightData.ambientLight = ambient; }

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled) { m_enabled = enabled; }

private:
    // Build cache key from clientId and category
    uint32_t makeKey(uint16 clientId, ThingCategory category) const;

    // Try to load a normal map from disk
    ImagePtr loadNormalMap(uint16 clientId, ThingCategory category);

    std::unordered_map<uint32_t, ImagePtr> m_normalMaps;
    std::unordered_map<uint32_t, bool> m_checked; // tracks which IDs we already tried loading
    ImagePtr m_defaultNormalMap;
    NormalMapLightData m_lightData;
    bool m_enabled = false;
};

extern NormalMapManager g_normalMaps;

#endif
