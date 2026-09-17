#ifdef WITH_ULTRALIGHT

#include "uiwebview.h"
#include "ultralightmanager.h"
#include "graphics.h"
#include "texture.h"
#include "image.h"
#include "graph.h"
#include <framework/core/logger.h>
#include <framework/core/eventdispatcher.h>
#include <framework/graphics/painter.h>
#include <framework/platform/platformwindow.h>
#include <Ultralight/Bitmap.h>
#include <Ultralight/Platform/Surface.h>
#include <mutex>

static std::string toStr(const ultralight::String& str) {
    ultralight::String8 utf8 = str.utf8();
    return std::string(utf8.data(), utf8.size());
}

static ultralight::MouseEvent::Button mapMouseButton(Fw::MouseButton button) {
    switch (button) {
        case Fw::MouseLeftButton:   return ultralight::MouseEvent::kButton_Left;
        case Fw::MouseRightButton:  return ultralight::MouseEvent::kButton_Right;
        case Fw::MouseMidButton:    return ultralight::MouseEvent::kButton_Middle;
        default: return ultralight::MouseEvent::kButton_None;
    }
}

static uint32_t mapModifiers(int modifiers) {
    uint32_t result = 0;
    if (modifiers & Fw::KeyboardShiftModifier) result |= ultralight::KeyEvent::kMod_ShiftKey;
    if (modifiers & Fw::KeyboardCtrlModifier)  result |= ultralight::KeyEvent::kMod_CtrlKey;
    if (modifiers & Fw::KeyboardAltModifier)   result |= ultralight::KeyEvent::kMod_AltKey;
    return result;
}

// ── UIWebView ────────────────────────────────────────────────────────────────

UIWebView::UIWebView() = default;
UIWebView::~UIWebView() {
    if (m_created) {
        UltralightManager::instance().decActiveViews();
    }
    m_view = nullptr;
    m_texture = nullptr;
}

class UIWebViewLoadListener : public ultralight::LoadListener {
public:
    void OnDOMReady(ultralight::View* caller, uint64_t frame_id, bool is_main_frame, const ultralight::String& url) override {
        g_logger.info("[UIWebView] OnDOMReady event received!");
    }
    void OnFinishLoading(ultralight::View* caller, uint64_t frame_id, bool is_main_frame, const ultralight::String& url) override {
        g_logger.info("[UIWebView] OnFinishLoading event received!");
    }
    void OnFailLoading(ultralight::View* caller, uint64_t frame_id, bool is_main_frame, const ultralight::String& url, const ultralight::String& description, const ultralight::String& error_domain, int error_code) override {
        g_logger.error("[UIWebView] OnFailLoading: " + std::string(description.utf8().data()));
    }
};
static UIWebViewLoadListener g_webViewLoadListener;

void UIWebView::create(int width, int height) {
    if (m_created) return;
    g_logger.info("[UIWebView] create(" + std::to_string(width) + "x" + std::to_string(height) + ")");

    try {
        auto& mgr = UltralightManager::instance();
        if (!mgr.isInitialized()) {
            mgr.init();
        }
        if (!mgr.isInitialized()) {
            g_logger.error("[UIWebView] Ultralight not initialized");
            return;
        }

        auto renderer = mgr.getRenderer();
        if (!renderer) {
            g_logger.error("[UIWebView] No renderer");
            return;
        }

        ultralight::ViewConfig config;
        config.initial_device_scale = 1.0;
        config.is_transparent = false;
        config.enable_images = true;
        config.enable_javascript = true;
        config.is_accelerated = false;
        config.initial_focus = false;

        int alignedWidth = std::max(16, (width / 16) * 16);
        int alignedHeight = std::max(16, (height / 16) * 16);
        g_logger.info("[UIWebView] CreateView with aligned size: " + std::to_string(alignedWidth) + "x" + std::to_string(alignedHeight));

        m_view = renderer->CreateView(alignedWidth, alignedHeight, config, renderer->default_session());
        if (!m_view) {
            g_logger.error("[UIWebView] CreateView returned null");
            return;
        }
        m_view->set_load_listener(&g_webViewLoadListener);
        g_logger.info("[UIWebView] CreateView OK");

        m_viewWidth = alignedWidth;
        m_viewHeight = alignedHeight;
        m_created = true;
        m_needsTextureUpdate = true;
        mgr.incActiveViews();
        g_logger.info("[UIWebView] Created OK");

    } catch (const std::exception& e) {
        g_logger.error("[UIWebView] Exception in create: " + std::string(e.what()));
    } catch (...) {
        g_logger.error("[UIWebView] Unknown exception in create");
    }
}

void UIWebView::loadHTML(const std::string& html, const std::string& baseUrl) {
    if (!m_view) { g_logger.error("[UIWebView] loadHTML: m_view is null"); return; }
    try {
        g_logger.info("[UIWebView] loadHTML: size=" + std::to_string(html.size()));
        ultralight::String ulHtml(html.c_str(), html.size());
        std::string base = baseUrl.empty() ? "http://localhost/" : baseUrl;
        ultralight::String ulBase(base.c_str(), base.size());
        m_view->LoadHTML(ulHtml, ulBase);
        g_logger.info("[UIWebView] loadHTML: OK");
        m_needsTextureUpdate = true;
    } catch (const std::exception& e) {
        g_logger.error("[UIWebView] loadHTML exception: " + std::string(e.what()));
    } catch (...) {
        g_logger.error("[UIWebView] loadHTML unknown exception");
    }
}

void UIWebView::loadURL(const std::string& url) {
    if (!m_view) return;
    try {
        m_view->LoadURL(ultralight::String(url.c_str(), url.size()));
    } catch (...) {}
}

std::string UIWebView::executeScript(const std::string& script) {
    if (!m_view || m_view->is_loading()) return "";
    try {
        ultralight::String exception;
        auto result = m_view->EvaluateScript(ultralight::String(script.c_str(), script.size()), &exception);
        return toStr(result);
    } catch (...) { return ""; }
}

void UIWebView::reload() { if (m_view) m_view->Reload(); }

void UIWebView::resizeView(int width, int height) {
    if (!m_view || width <= 0 || height <= 0) return;
    try {
        m_view->Resize(width, height);
        m_viewWidth = width;
        m_viewHeight = height;
        m_needsTextureUpdate = true;
    } catch (...) {}
}

void UIWebView::setTransparent(bool t) { m_transparent = t; }
void UIWebView::setJavaScriptEnabled(bool e) { m_jsEnabled = e; }
std::string UIWebView::getURL() { return m_view ? toStr(m_view->url()) : ""; }
std::string UIWebView::getTitle() { return m_view ? toStr(m_view->title()) : ""; }
bool UIWebView::isLoading() { return m_view ? m_view->is_loading() : false; }
void UIWebView::setOnURLChange(const std::string& cb) { m_jsCallbackName = cb; }

// ── CPU pixel copy ───────────────────────────────────────────────────────────

void UIWebView::copyPixelsFromSurface() {
    if (!m_view) return;
    try {
        auto* surface = m_view->surface();
        if (!surface) return;
        if (surface->dirty_bounds().IsEmpty()) return;

        uint32_t w = surface->width();
        uint32_t h = surface->height();
        uint32_t stride = surface->row_bytes();
        if (w == 0 || h == 0 || stride < w * 4) return;

        const unsigned char* raw = static_cast<const unsigned char*>(surface->LockPixels());
        if (!raw) return;

        {
            std::lock_guard<std::mutex> lock(m_pixelMutex);
            m_pendingPixels.resize(w * h * 4);
            m_pendingWidth = (int)w;
            m_pendingHeight = (int)h;

            for (uint32_t y = 0; y < h; ++y) {
                const unsigned char* srcRow = raw + (y * stride);
                unsigned char* dstRow = m_pendingPixels.data() + (y * w * 4);
                for (uint32_t x = 0; x < w; ++x) {
                    dstRow[x * 4 + 0] = srcRow[x * 4 + 2]; // R (from BGRA)
                    dstRow[x * 4 + 1] = srcRow[x * 4 + 1]; // G
                    dstRow[x * 4 + 2] = srcRow[x * 4 + 0]; // B
                    dstRow[x * 4 + 3] = srcRow[x * 4 + 3]; // A
                }
            }
            m_hasPendingPixels = true;
        }

        surface->UnlockPixels();
        surface->ClearDirtyBounds();
        m_needsTextureUpdate = false;
    } catch (...) {}
}

void UIWebView::pendingTextureUpdate() {
    if (!m_view) return;
    copyPixelsFromSurface();
}

// ── Rendering ────────────────────────────────────────────────────────────────

void UIWebView::drawSelf(Fw::DrawPane drawPane) {
    if (drawPane != Fw::ForegroundPane) return;
    UIWidget::drawSelf(drawPane);
    if (!m_created) return;

    {
        std::lock_guard<std::mutex> lock(m_pixelMutex);
        if (m_hasPendingPixels && m_pendingWidth > 0 && m_pendingHeight > 0) {
            try {
                ImagePtr img(new Image(Size(m_pendingWidth, m_pendingHeight), 4, m_pendingPixels.data()));
                if (m_texture && m_texture->getWidth() == m_pendingWidth && m_texture->getHeight() == m_pendingHeight) {
                    m_texture->replace(img);
                } else {
                    m_texture = TexturePtr(new Texture(img));
                }
            } catch (...) {}
            m_hasPendingPixels = false;
        }
    }

    if (!m_texture || m_texture->isEmpty()) return;

    Rect screenCoords = getPaddingRect();
    Rect srcRect(0, 0, m_viewWidth, m_viewHeight);
    g_painter->drawTexturedRect(screenCoords, m_texture, srcRect);
}

// ── Input Events ─────────────────────────────────────────────────────────────

bool UIWebView::onMousePress(const Point& mousePos, Fw::MouseButton button) {
    if (!m_view) return false;
    Rect r = getPaddingRect();
    ultralight::MouseEvent evt;
    evt.type = ultralight::MouseEvent::kType_MouseDown;
    evt.x = mousePos.x - r.left();
    evt.y = mousePos.y - r.top();
    evt.button = mapMouseButton(button);
    m_view->FireMouseEvent(evt);
    focus();
    return true;
}

bool UIWebView::onMouseRelease(const Point& mousePos, Fw::MouseButton button) {
    if (!m_view) return false;
    Rect r = getPaddingRect();
    ultralight::MouseEvent evt;
    evt.type = ultralight::MouseEvent::kType_MouseUp;
    evt.x = mousePos.x - r.left();
    evt.y = mousePos.y - r.top();
    evt.button = mapMouseButton(button);
    m_view->FireMouseEvent(evt);
    return true;
}

bool UIWebView::onMouseMove(const Point& mousePos, const Point& /*mouseMoved*/) {
    if (!m_view) return false;
    Rect r = getPaddingRect();
    ultralight::MouseEvent evt;
    evt.type = ultralight::MouseEvent::kType_MouseMoved;
    evt.x = mousePos.x - r.left();
    evt.y = mousePos.y - r.top();
    evt.button = ultralight::MouseEvent::kButton_None;
    m_view->FireMouseEvent(evt);
    return true;
}

bool UIWebView::onMouseWheel(const Point& /*mousePos*/, Fw::MouseWheelDirection direction) {
    if (!m_view) return false;
    ultralight::ScrollEvent evt;
    evt.type = ultralight::ScrollEvent::kType_ScrollByPixel;
    evt.delta_x = 0;
    evt.delta_y = (direction == Fw::MouseWheelUp) ? -100 : 100;
    m_view->FireScrollEvent(evt);
    return true;
}

bool UIWebView::onKeyPress(uchar keyCode, int keyboardModifiers, int autoRepeatTicks) {
    if (!m_view) return false;
    ultralight::KeyEvent evt;
    evt.type = ultralight::KeyEvent::kType_RawKeyDown;
    evt.virtual_key_code = static_cast<int>(keyCode);
    evt.modifiers = mapModifiers(keyboardModifiers);
    evt.native_key_code = keyCode;
    evt.is_keypad = false;
    evt.is_auto_repeat = (autoRepeatTicks > 0);
    evt.is_system_key = false;
    m_view->FireKeyEvent(evt);
    return true;
}

bool UIWebView::onKeyDown(uchar keyCode, int keyboardModifiers) {
    if (!m_view) return false;
    ultralight::KeyEvent evt;
    evt.type = ultralight::KeyEvent::kType_RawKeyDown;
    evt.virtual_key_code = static_cast<int>(keyCode);
    evt.modifiers = mapModifiers(keyboardModifiers);
    evt.native_key_code = keyCode;
    evt.is_keypad = false;
    evt.is_auto_repeat = false;
    evt.is_system_key = false;
    m_view->FireKeyEvent(evt);
    return true;
}

bool UIWebView::onKeyUp(uchar keyCode, int keyboardModifiers) {
    if (!m_view) return false;
    ultralight::KeyEvent evt;
    evt.type = ultralight::KeyEvent::kType_KeyUp;
    evt.virtual_key_code = static_cast<int>(keyCode);
    evt.modifiers = mapModifiers(keyboardModifiers);
    evt.native_key_code = keyCode;
    evt.is_keypad = false;
    evt.is_auto_repeat = false;
    evt.is_system_key = false;
    m_view->FireKeyEvent(evt);
    return true;
}

bool UIWebView::onKeyText(const std::string& keyText) {
    if (!m_view || keyText.empty()) return false;
    ultralight::KeyEvent evt;
    evt.type = ultralight::KeyEvent::kType_Char;
    evt.text = ultralight::String(keyText.c_str(), keyText.size());
    evt.unmodified_text = evt.text;
    evt.modifiers = 0;
    evt.is_keypad = false;
    evt.is_auto_repeat = false;
    evt.is_system_key = false;
    m_view->FireKeyEvent(evt);
    return true;
}

void UIWebView::onGeometryChange(const Rect& oldRect, const Rect& newRect) {
    UIWidget::onGeometryChange(oldRect, newRect);
    if (m_created && m_view) {
        Size sz = newRect.size();
        if (sz.width() != m_viewWidth || sz.height() != m_viewHeight)
            resizeView(sz.width(), sz.height());
    }
}

void UIWebView::onStyleApply(const std::string& styleName, const OTMLNodePtr& styleNode) {
    UIWidget::onStyleApply(styleName, styleNode);
    for (const OTMLNodePtr& node : styleNode->children()) {
        const std::string& tag = node->tag();
        if (tag == "html-content") loadHTML(node->value<std::string>());
        else if (tag == "url") loadURL(node->value<std::string>());
        else if (tag == "transparent") setTransparent(node->value<bool>());
    }
}

#endif // WITH_ULTRALIGHT
