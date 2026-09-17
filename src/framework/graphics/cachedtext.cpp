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

#include "cachedtext.h"
#include "painter.h"
#include "fontmanager.h"
#include "bitmapfont.h"

CachedText::CachedText()
{
    m_font = g_fonts.getDefaultFont();
    m_align = Fw::AlignCenter;
}

void CachedText::draw(const Rect& rect, const Color& color)
{
    if(!m_font)
        return;

    if(m_textMustRecache || m_textCachedScreenCoords != rect) {
        m_textMustRecache = false;
        m_textCachedScreenCoords = rect;
    }

    if (m_textColors.empty()) {
        m_font->drawText(m_text, m_textCachedScreenCoords, Fw::AlignCenter, color);
    } else {
        m_font->drawColoredText(m_text, m_textCachedScreenCoords, Fw::AlignCenter, m_textColors);
    }
}

void CachedText::drawWithHighlight(const Rect& rect, const Color& baseColor, const Color& highlightColor, float highlightPos, float highlightWidth)
{
    if (!m_font || m_text.empty())
        return;

    if (m_textMustRecache || m_textCachedScreenCoords != rect) {
        m_textMustRecache = false;
        m_textCachedScreenCoords = rect;
    }

    int textLen = static_cast<int>(m_text.length());
    if (textLen == 0) return;

    // Wrap highlight position
    while (highlightPos < 0) highlightPos += textLen;
    while (highlightPos >= textLen) highlightPos -= textLen;

    // Build per-character color array using smooth cosine gradient
    std::vector<std::pair<int, Color>> textColors;
    textColors.reserve(textLen);

    for (int i = 0; i < textLen; ++i) {
        float dist = std::abs(static_cast<float>(i) - highlightPos);
        float wrapDist = textLen - dist;
        dist = std::min(dist, wrapDist);

        float t = 0.0f;
        if (dist < highlightWidth)
            t = (std::cos(dist / highlightWidth * 3.14159f) + 1.0f) / 2.0f;

        uint8_t r = static_cast<uint8_t>(baseColor.r() + (highlightColor.r() - baseColor.r()) * t);
        uint8_t g = static_cast<uint8_t>(baseColor.g() + (highlightColor.g() - baseColor.g()) * t);
        uint8_t b = static_cast<uint8_t>(baseColor.b() + (highlightColor.b() - baseColor.b()) * t);
        uint8_t a = static_cast<uint8_t>(baseColor.a() + (highlightColor.a() - baseColor.a()) * t);

        textColors.emplace_back(i + 1, Color(r, g, b, a));
    }

    m_font->drawColoredText(m_text, m_textCachedScreenCoords, Fw::AlignCenter, textColors);
}

void CachedText::setColoredText(const std::vector<std::string>& texts)
{
    m_text = "";
    m_textColors.clear();
    for (size_t i = 0, p = 0; i < texts.size() - 1; i += 2) {
        Color c(Color::white);
        stdext::cast<Color>(texts[i + 1], c);

        // normaliza antes de contar os bytes, senao os offsets de cor ficariam
        // deslocados em relacao ao texto desenhado
        std::string fragment = texts[i];
        stdext::ensure_latin1(fragment);
        m_text += fragment;
        for (auto& ch : fragment) {
            if ((uint8)ch >= 32)
                p += 1;
        }
        m_textColors.push_back(std::make_pair(p, c));
    }
    update();
}

void CachedText::update()
{
    if(m_font)
        m_textSize = m_font->calculateTextRectSize(m_text);
    m_textMustRecache = true;
}

void CachedText::wrapText(int maxWidth)
{
    if(m_font) {
        m_text = m_font->wrapText(m_text, maxWidth, m_textColors.empty() ? nullptr : &m_textColors);
        update();
    }
}
