#ifndef ULTRALIGHT_MANAGER_H
#define ULTRALIGHT_MANAGER_H

#ifdef WITH_ULTRALIGHT

#include <memory>
#include <Ultralight/Ultralight.h>
#include <framework/luaengine/luaobject.h>

class UltralightManager : public LuaObject {
public:
    UltralightManager();
    ~UltralightManager();

    void init();
    void terminate();

    ultralight::RefPtr<ultralight::Renderer> getRenderer() { return m_renderer; }

    void update();
    void render();

    void incActiveViews() { ++m_activeViews; }
    void decActiveViews() { if (m_activeViews > 0) --m_activeViews; }
    bool hasActiveViews() const { return m_activeViews > 0; }

    bool isInitialized() { return m_initialized; }

    static UltralightManager& instance();

private:
    ultralight::RefPtr<ultralight::Renderer> m_renderer;
    bool m_initialized = false;
    int m_activeViews = 0;
};

extern UltralightManager g_ultralightManager;

#endif // WITH_ULTRALIGHT
#endif // ULTRALIGHT_MANAGER_H
