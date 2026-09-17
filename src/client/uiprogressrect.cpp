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

#include "uiprogressrect.h"
#include <framework/otml/otml.h>
#include <framework/const.h>
#include <framework/core/clock.h>
#include <framework/graphics/graphics.h>
#include <framework/graphics/fontmanager.h>
#include <cmath>

UIProgressRect::UIProgressRect()
{
    m_percent = 0;
}

void UIProgressRect::drawSelf(Fw::DrawPane drawPane)
{
    if(drawPane != Fw::ForegroundPane)
        return;

    // todo: check +1 to right/bottom
    // todo: add smooth
    Rect drawRect = getPaddingRect();

    if(!m_ring) {
        // modo original: fatia preenchida (usado pela janela de cooldowns)

        // 0% - 12.5% (12.5)
        // triangle from top center, to top right (var x)
        if(m_percent < 12.5) {
            Point var = Point(std::max<int>(m_percent - 0.0, 0.0) * (drawRect.right() - drawRect.horizontalCenter()) / 12.5, 0);
            g_drawQueue->addFilledTriangle(drawRect.center(), drawRect.topRight() + Point(1,0), drawRect.topCenter() + var, m_backgroundColor);
        }

        // 12.5% - 37.5% (25)
        // triangle from top right to bottom right (var y)
        if(m_percent < 37.5) {
            Point var = Point(0, std::max<int>(m_percent - 12.5, 0.0) * (drawRect.bottom() - drawRect.top()) / 25.0);
            g_drawQueue->addFilledTriangle(drawRect.center(), drawRect.bottomRight() + Point(1,1), drawRect.topRight() + var + Point(1,0), m_backgroundColor);
        }

        // 37.5% - 62.5% (25)
        // triangle from bottom right to bottom left (var x)
        if(m_percent < 62.5) {
            Point var = Point(std::max<int>(m_percent - 37.5, 0.0) * (drawRect.right() - drawRect.left()) / 25.0, 0);
            g_drawQueue->addFilledTriangle(drawRect.center(), drawRect.bottomLeft() + Point(0,1), drawRect.bottomRight() - var + Point(1,1), m_backgroundColor);
        }

        // 62.5% - 87.5% (25)
        // triangle from bottom left to top left
        if(m_percent < 87.5) {
            Point var = Point(0, std::max<int>(m_percent - 62.5, 0.0) * (drawRect.bottom() - drawRect.top()) / 25.0);
            g_drawQueue->addFilledTriangle(drawRect.center(), drawRect.topLeft(), drawRect.bottomLeft() - var + Point(0,1), m_backgroundColor);
        }

        // 87.5% - 100% (12.5)
        // triangle from top left to top center
        if(m_percent < 100) {
            Point var = Point(std::max<int>(m_percent - 87.5, 0.0) * (drawRect.horizontalCenter() - drawRect.left()) / 12.5, 0);
            g_drawQueue->addFilledTriangle(drawRect.center(), drawRect.topCenter(), drawRect.topLeft() + var, m_backgroundColor);
        }
    }

    drawImage(m_rect);
    drawBorder(m_rect);
    drawIcon(m_rect);
    drawText(m_rect);

    // percent efetivo: se existe cooldown nativo por tempo, o anel drena
    // sozinho a cada frame (fluido); senao usa o percent definido via Lua
    float pct = m_percent;
    if(m_autoTotalMs > 0) {
        ticks_t elapsed = g_clock.millis() - m_autoStartMs;
        if(elapsed >= m_autoTotalMs) {
            m_autoTotalMs = 0;
            pct = 0.0f;
        } else {
            pct = (float)(m_autoTotalMs - elapsed) * 100.0f / (float)m_autoTotalMs;
        }
    }

    // relogio QUADRADO por cima de tudo: uma linha acompanhando a borda da
    // skill (topo -> direita -> baixo -> esquerda), meio vazio, encolhendo
    // de 100 (contorno completo) ate 0 (liberou).
    if(m_ring && pct > 0.05f) {
        drawBorderSweep(drawRect, pct);
    }
}

void UIProgressRect::setAutoCountdown(int totalMs)
{
    if(totalMs <= 0) {
        m_autoTotalMs = 0;
        return;
    }
    m_autoStartMs = g_clock.millis();
    m_autoTotalMs = totalMs;
}

// Desenha a borda neon ao redor do QUADRADO (relogio quadrado): comeca no
// canto superior esquerdo e percorre o perimetro no sentido horario. O
// percent define quanto da borda esta acesa: 100 = quadrado inteiro, 0 =
// nada. Efeito neon = nucleo brilhante + halos translucidos mais largos.
void UIProgressRect::drawBorderSweep(const Rect& drawRect, float percent)
{
    if(m_ringThickness <= 0 || percent <= 0.05f)
        return;

    const float x1 = (float)drawRect.left();
    const float y1 = (float)drawRect.top();
    const float x2 = (float)drawRect.right();
    const float y2 = (float)drawRect.bottom();
    const float w = x2 - x1;
    const float h = y2 - y1;
    const float perimeter = 2.0f * (w + h);
    if(perimeter <= 1.0f)
        return;

    const float maxThickness = std::min(w, h) / 2.0f;
    const float covered =
        stdext::clamp<float>((double)percent, 0.0, 100.0) / 100.0f * perimeter;

    // arestas do perimetro: (dx, dy, normal interno x, normal interno y, comprimento)
    struct Edge { float dx, dy, nx, ny, len; };
    const Edge edges[4] = {
        {  1.0f,  0.0f,  0.0f,  1.0f, w }, // topo: esquerda -> direita
        {  0.0f,  1.0f, -1.0f,  0.0f, h }, // direita: topo -> baixo
        { -1.0f,  0.0f,  0.0f, -1.0f, w }, // baixo: direita -> esquerda
        {  0.0f, -1.0f,  1.0f,  0.0f, h }, // esquerda: baixo -> topo
    };

    // desenha uma faixa (banda) de espessura/alpha dados ao longo do trecho aceso
    auto drawBand = [&](float thickness, const Color& color) {
        if(thickness <= 0.0f)
            return;
        thickness = std::min<float>(thickness, maxThickness);
        float remaining = covered;
        float sx = x1, sy = y1; // inicio = canto superior esquerdo
        for(int e = 0; e < 4 && remaining > 0.01f; ++e) {
            const Edge& ed = edges[e];
            const float seg = std::min<float>(remaining, ed.len);
            const float ex = sx + ed.dx * seg;
            const float ey = sy + ed.dy * seg;

            const Point o0 = Point((int)(sx + 0.5f), (int)(sy + 0.5f));
            const Point o1 = Point((int)(ex + 0.5f), (int)(ey + 0.5f));
            const Point i0 = Point((int)(sx + ed.nx * thickness + 0.5f),
                                   (int)(sy + ed.ny * thickness + 0.5f));
            const Point i1 = Point((int)(ex + ed.nx * thickness + 0.5f),
                                   (int)(ey + ed.ny * thickness + 0.5f));

            g_drawQueue->addFilledTriangle(i0, o0, o1, color);
            g_drawQueue->addFilledTriangle(i0, o1, i1, color);

            remaining -= seg;
            sx = ex;
            sy = ey;
        }
    };

    const float base = (float)m_ringThickness;
    const float ca = m_backgroundColor.aF(); // alpha 0..1
    const Color& c = m_backgroundColor;

    // camadas do neon: halo largo bem translucido -> halo medio -> nucleo opaco
    drawBand(base + 4.0f, Color(c.rF(), c.gF(), c.bF(), ca * 0.16f));
    drawBand(base + 2.0f, Color(c.rF(), c.gF(), c.bF(), ca * 0.40f));
    drawBand(base + 0.5f, Color(c.rF(), c.gF(), c.bF(), ca * 0.75f));
    drawBand(base,         Color(c.rF(), c.gF(), c.bF(), ca));
}

void UIProgressRect::setPercent(float percent)
{
    m_percent = stdext::clamp<float>((double)percent, 0.0, 100.0);
}

void UIProgressRect::onStyleApply(const std::string& styleName, const OTMLNodePtr& styleNode)
{
    UIWidget::onStyleApply(styleName, styleNode);

    for(const OTMLNodePtr& node : styleNode->children()) {
        if(node->tag() == "percent")
            setPercent(node->value<float>());
        else if(node->tag() == "ring")
            setRing(node->value<bool>());
        else if(node->tag() == "ring-thickness")
            setRingThickness(node->value<int>());
    }
}
