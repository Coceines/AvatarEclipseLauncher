#ifdef WITH_ULTRALIGHT

#include <framework/core/application.h>
#include <framework/luaengine/luainterface.h>
#include <framework/graphics/ultralightmanager.h>
#include <framework/graphics/uiwebview.h>

void Application::registerLuaFunctionsUltralight()
{
    // UltralightManager singleton
    g_lua.registerSingletonClass("g_ultralight");
    g_lua.bindSingletonFunction("g_ultralight", "isInitialized",
        &UltralightManager::isInitialized, &g_ultralightManager);
    g_lua.bindSingletonFunction("g_ultralight", "init",
        &UltralightManager::init, &g_ultralightManager);
    g_lua.bindSingletonFunction("g_ultralight", "terminate",
        &UltralightManager::terminate, &g_ultralightManager);

    // UIWebView widget
    g_lua.registerClass<UIWebView, UIWidget>();

    // Static factory
    g_lua.bindClassStaticFunction<UIWebView>("create", []{
        return UIWebViewPtr(new UIWebView());
    });

    // Member functions — use actual member pointers
    g_lua.bindClassMemberFunction<UIWebView>("init", &UIWebView::create);
    g_lua.bindClassMemberFunction<UIWebView>("loadHTML", &UIWebView::loadHTML);
    g_lua.bindClassMemberFunction<UIWebView>("loadURL", &UIWebView::loadURL);
    g_lua.bindClassMemberFunction<UIWebView>("executeScript", &UIWebView::executeScript);
    g_lua.bindClassMemberFunction<UIWebView>("reload", &UIWebView::reload);
    g_lua.bindClassMemberFunction<UIWebView>("resizeView", &UIWebView::resizeView);
    g_lua.bindClassMemberFunction<UIWebView>("getURL", &UIWebView::getURL);
    g_lua.bindClassMemberFunction<UIWebView>("getTitle", &UIWebView::getTitle);
    g_lua.bindClassMemberFunction<UIWebView>("isLoading", &UIWebView::isLoading);
    g_lua.bindClassMemberFunction<UIWebView>("setTransparent", &UIWebView::setTransparent);
    g_lua.bindClassMemberFunction<UIWebView>("setJavaScriptEnabled", &UIWebView::setJavaScriptEnabled);
    g_lua.bindClassMemberFunction<UIWebView>("pendingTextureUpdate", &UIWebView::pendingTextureUpdate);
}

#endif // WITH_ULTRALIGHT
