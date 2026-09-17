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

#ifndef THINGTYPEMANAGER_H
#define THINGTYPEMANAGER_H

#include <atomic>
#include <unordered_map>
#include <framework/global.h>
#include <framework/core/declarations.h>
#include <framework/core/eventdispatcher.h>

#include "thingtype.h"
#include "itemtype.h"

class ThingTypeManager
{
public:
    void init();
    void terminate();
    void check();
    void unloadTextures();

    bool loadDat(std::string file);
    bool loadOtml(std::string file);
    void loadOtb(const std::string& file);
    void loadXml(const std::string& file);
    void parseItemType(uint16 id, TiXmlElement *elem);

#ifdef WITH_ENCRYPTION
    void saveDat(std::string fileName);
    void dumpTextures(std::string dir);
    void replaceTextures(std::string dir);
#endif

    void addItemType(const ItemTypePtr& itemType);
    const ItemTypePtr& findItemTypeByClientId(uint16 id);
    const ItemTypePtr& findItemTypeByName(std::string name);
    ItemTypeList findItemTypesByName(std::string name);
    ItemTypeList findItemTypesByString(std::string str);

    std::set<int> getMarketCategories()
    {
        return m_marketCategories;
    }

    const ThingTypePtr& getNullThingType() { return m_nullThingType; }
    const ItemTypePtr& getNullItemType() { return m_nullItemType; }

    const ThingTypePtr& getThingType(uint16 id, ThingCategory category);
    const ItemTypePtr& getItemType(uint16 id);
    ThingType* rawGetThingType(uint16 id, ThingCategory category) { 
        VALIDATE(id < m_thingTypes[category].size());
        return m_thingTypes[category][id].get(); 
    }
    ItemType* rawGetItemType(uint16 id) { 
        VALIDATE(id < m_itemTypes.size());
        return m_itemTypes[id].get();
    }

    ThingTypeList findThingTypeByAttr(ThingAttr attr, ThingCategory category);
    ItemTypeList findItemTypeByCategory(ItemCategory category);

    const ThingTypeList& getThingTypes(ThingCategory category);
    const ItemTypeList& getItemTypes() { return m_itemTypes; }

    uint32 getDatSignature() { return m_datSignature; }
    uint32 getOtbMajorVersion() { return m_otbMajorVersion; }
    uint32 getOtbMinorVersion() { return m_otbMinorVersion; }
    uint16 getContentRevision() { return m_contentRevision; }

    bool isDatLoaded() { return m_datLoaded; }
    bool isXmlLoaded() { return m_xmlLoaded; }
    bool isOtbLoaded() { return m_otbLoaded; }

    bool isValidDatId(uint16 id, ThingCategory category) { return id >= 1 && id < m_thingTypes[category].size(); }
    bool isValidOtbId(uint16 id) { return id >= 1 && id < m_itemTypes.size(); }

    // Preloads every thing type texture in background chunks (graphics thread)
    // so walking into new areas never stalls on texture creation.
    // NOTE: disabled on purpose - the full .dat has ~19k thing types and with
    // HD mode (xBRZ) the client is 32-bit, so preloading ALL of them throws
    // bad_alloc (out of memory) and dies. Use preloadItemTextures() instead.
    void preloadTextures();

    // Preloads textures ONLY for the given item ids (the ones actually used by
    // the downloaded world map). A few thousand textures fit in 32-bit memory
    // fine, and it removes the walking stutter without OOM.
    void preloadItemTextures(const std::vector<uint16>& itemIds);

    // Preload progress (thread-safe, read from Lua to drive the loading screen)
    float getPreloadProgress() { return m_preloadTotal.load() > 0 ? (float)m_preloadDone.load() / (float)m_preloadTotal.load() : 0.0f; }
    int getPreloadPhase() { return m_preloadPhase.load(); }
    bool isPreloadFinished() { return m_preloadFinished.load(); }

    // Safe ItemType lookup: returns null ItemType if not found (no error log)
    const ItemTypePtr& tryGetItemType(uint16 id) { if(id >= m_itemTypes.size() || m_itemTypes[id] == m_nullItemType) return m_nullItemType; return m_itemTypes[id]; }

    void setItemShader(uint16 clientId, const std::string& shader) {
        if (shader.empty())
            m_itemShaders.erase(clientId);
        else
            m_itemShaders[clientId] = shader;
    }
    std::string getItemShader(uint16 clientId) {
        auto it = m_itemShaders.find(clientId);
        if (it != m_itemShaders.end())
            return it->second;
        return std::string();
    }
    void clearItemShaders() {
        m_itemShaders.clear();
    }

private:
    std::unordered_map<uint16, std::string> m_itemShaders;
    ThingTypeList m_thingTypes[ThingLastCategory];
    ItemTypeList m_reverseItemTypes;
    ItemTypeList m_itemTypes;
    std::set<int> m_marketCategories;

    ThingTypePtr m_nullThingType;
    ItemTypePtr m_nullItemType;

    bool m_datLoaded;
    bool m_xmlLoaded;
    bool m_otbLoaded;

    uint32 m_otbMinorVersion;
    uint32 m_otbMajorVersion;
    uint32 m_datSignature;
    uint16 m_contentRevision;

    ScheduledEventPtr m_checkEvent;
    size_t m_checkIndex[ThingLastCategory];

    void preloadTextureBatch();
    size_t m_preloadIndex = 0;
    size_t m_preloadSkipped = 0;
    std::vector<std::pair<uint16, ThingCategory>> m_preloadList;
    std::atomic<size_t> m_preloadTotal = 0;
    std::atomic<size_t> m_preloadDone = 0;
    std::atomic<int> m_preloadPhase = 0;
    std::atomic<bool> m_preloadFinished = false;
};

extern ThingTypeManager g_things;

#endif
