#include "uieffect.h"
#include "spritemanager.h"
#include <framework/graphics/drawqueue.h>

void UIEffect::drawSelf(Fw::DrawPane drawPane)
{
    if (drawPane != Fw::ForegroundPane)
        return;

    UIWidget::drawSelf(drawPane);

    if (m_effect && m_effect->getId() != 0) {
        Rect drawRect = Rect(getPaddingRect().topLeft(), getSize() * m_scale);
        m_effect->draw(drawRect.topLeft(), 0, 0, true);
    }
}

void UIEffect::setEffect(const EffectPtr& effect)
{
    if (effect && g_things.isValidDatId(effect->getId(), ThingCategoryEffect)) {
        m_effect = effect;
    } else {
        m_effect = nullptr;
    }
}

void UIEffect::onStyleApply(const std::string& styleName, const OTMLNodePtr& styleNode)
{
    UIWidget::onStyleApply(styleName, styleNode);

    for (const OTMLNodePtr& node : styleNode->children()) {
        if (node->tag() == "scale") {
            setScale(node->value<float>());
        }
    }
}

void UIEffect::onGeometryChange(const Rect& oldRect, const Rect& newRect)
{
    UIWidget::onGeometryChange(oldRect, newRect);
}
