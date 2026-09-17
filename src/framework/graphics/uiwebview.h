#ifndef UIWEBVIEW_H
#define UIWEBVIEW_H

#ifdef WITH_ULTRALIGHT

#include <string>
#include <functional>
#include <vector>
#include <mutex>
#include <framework/ui/uiwidget.h>
#include <framework/graphics/declarations.h>
#include <Ultralight/Ultralight.h>

class UIWebView : public UIWidget {
public:
    UIWebView();
    ~UIWebView() override;

    void create(int width, int height);
    void loadHTML(const std::string& html, const std::string& baseUrl = "");
    void loadURL(const std::string& url);
    std::string executeScript(const std::string& script);
    void reload();
    void resizeView(int width, int height);
    void setTransparent(bool transparent);
    void setJavaScriptEnabled(bool enabled);
    std::string getURL();
    std::string getTitle();
    bool isLoading();
    void setOnURLChange(const std::string& callbackName);

    void drawSelf(Fw::DrawPane drawPane) override;
    bool onMousePress(const Point& mousePos, Fw::MouseButton button) override;
    bool onMouseRelease(const Point& mousePos, Fw::MouseButton button) override;
    bool onMouseMove(const Point& mousePos, const Point& mouseMoved) override;
    bool onMouseWheel(const Point& mousePos, Fw::MouseWheelDirection direction) override;
    bool onKeyPress(uchar keyCode, int keyboardModifiers, int autoRepeatTicks) override;
    bool onKeyDown(uchar keyCode, int keyboardModifiers) override;
    bool onKeyUp(uchar keyCode, int keyboardModifiers) override;
    bool onKeyText(const std::string& keyText) override;
    void onGeometryChange(const Rect& oldRect, const Rect& newRect) override;

    void pendingTextureUpdate();

protected:
    void onStyleApply(const std::string& styleName, const OTMLNodePtr& styleNode) override;

private:
    void copyPixelsFromSurface();

    ultralight::RefPtr<ultralight::View> m_view;
    TexturePtr m_texture;
    bool m_needsTextureUpdate = false;
    bool m_created = false;
    bool m_transparent = false;
    bool m_jsEnabled = true;
    int m_viewWidth = 0;
    int m_viewHeight = 0;
    std::string m_jsCallbackName;

    std::mutex m_pixelMutex;
    std::vector<unsigned char> m_pendingPixels;
    bool m_hasPendingPixels = false;
    int m_pendingWidth = 0;
    int m_pendingHeight = 0;
};

#endif // WITH_ULTRALIGHT
#endif // UIWEBVIEW_H
