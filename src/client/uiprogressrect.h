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

#ifndef UIPROGRESSRECT_H
#define UIPROGRESSRECT_H

#include "declarations.h"
#include <framework/ui/uiwidget.h>
#include "item.h"
#include <algorithm>

class UIProgressRect : public UIWidget
{
public:
    UIProgressRect();
    void drawSelf(Fw::DrawPane drawPane);

    void setPercent(float percent);
    float getPercent() { return m_percent; }

    // Modo "relogio quadrado": desenha apenas uma linha de contorno ao longo
    // da borda retangular da skill (meio vazio), percorrendo o perimetro no
    // sentido horario conforme o percent (100 = borda inteira ate 0 = vazio).
    void setRing(bool ring) { m_ring = ring; }
    void setRingThickness(int thickness) { m_ringThickness = std::max(1, thickness); }

    // Cooldown nativo FLUIDO: o anel drena sozinho por tempo, avaliado a cada
    // frame no draw (nao depende dos updates de 100ms do Lua). Passar o tempo
    // total em ms; zera/limpa sozinho ao terminar.
    void setAutoCountdown(int totalMs);
    void clearAutoCountdown() { m_autoTotalMs = 0; }

protected:
    void onStyleApply(const std::string& styleName, const OTMLNodePtr& styleNode);
    void drawBorderSweep(const Rect& drawRect, float percent);

    float m_percent;
    ticks_t m_autoStartMs = 0;
    ticks_t m_autoTotalMs = 0;
    bool m_ring = false;
    int m_ringThickness = 3;
};

#endif
