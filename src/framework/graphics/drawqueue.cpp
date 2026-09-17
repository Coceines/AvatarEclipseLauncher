#include <stack>
#include <framework/graphics/drawqueue.h>
#include <framework/graphics/painter.h>
#include <framework/graphics/atlas.h>
#include <framework/graphics/graphics.h>
#include <framework/graphics/framebuffermanager.h>
#include <framework/graphics/shadermanager.h>
#include <framework/graphics/shaders/shaders.h>
#include <framework/graphics/textrender.h>
#include <framework/graphics/drawcache.h>
#include <framework/graphics/image.h>
#include <client/spritemanager.h>
#include <client/outfit.h>
#include <client/normalmapmanager.h>

std::shared_ptr<DrawQueue> g_drawQueue;

void DrawQueueItemTextureCoords::draw()
{
    g_painter->setColor(m_color);
    g_painter->drawTextureCoords(m_coordsBuffer, m_texture);
}

bool DrawQueueItemTextureCoords::cache()
{
    if (!m_texture->canCache())
        return false;
    m_texture->update();

    uint64_t hash = 100 + m_texture->getUniqueId();
    bool drawNow = false;
    Point atlasPos = g_atlas.cache(hash, m_texture->getSize(), drawNow);
    if (atlasPos.x < 0) { return false; } // can't be cached
    if (drawNow) { g_drawCache.bind(); draw(atlasPos); }

    int size = m_coordsBuffer.getVertexCount();
    if (!g_drawCache.hasSpace(size))
        return false;

    g_drawCache.addTexturedCoords(m_coordsBuffer, atlasPos, m_color);
    return true;
}

void DrawQueueItemTextureCoords::draw(const Point& pos)
{
    g_painter->resetColor();
    g_painter->drawTexturedRect(Rect(pos, m_texture->getSize()), m_texture);
}

void DrawQueueItemColoredTextureCoords::draw()
{
    g_painter->drawTextureCoords(m_coordsBuffer, m_texture, &m_colors);
}

void DrawQueueItemImageWithShader::draw()
{
    if (!m_texture) return;
    PainterShaderProgramPtr shader = g_shaders.getShader(m_shader);
    if (!shader) {
        // Shader ausente (nome errado, falha de compilacao): desenha a imagem
        // normal com o image-color. Antes esse caminho nao desenhava nada, o
        // que deixava invisivel qualquer widget com image-shader quebrado.
        g_painter->setColor(m_color);
        g_painter->drawTextureCoords(m_coordsBuffer, m_texture);
        return;
    }

    g_painter->setShaderProgram(shader);
    shader->bindMultiTextures();
    g_painter->setColor(m_color);
    g_painter->drawTextureCoords(m_coordsBuffer, m_texture);
    g_painter->resetShaderProgram();
}

void DrawQueueItemImageWithShader::draw(const Point& pos)
{
    if (!m_texture) return;
    PainterShaderProgramPtr shader = g_shaders.getShader(m_shader);
    if (!shader) {
        g_painter->setColor(m_color);
        g_painter->drawTexturedRect(Rect(pos, m_texture->getSize()), m_texture);
        return;
    }

    g_painter->setShaderProgram(shader);
    shader->bindMultiTextures();
    g_painter->resetColor();
    g_painter->drawTexturedRect(Rect(pos, m_texture->getSize()), m_texture);
    g_painter->resetShaderProgram();
}

void DrawQueueItemTexturedRect::draw()
{
    if (m_isShadow) {
        Color shadowColor = Color(0, 0, 0, m_color.a() > 0 ? (m_color.a() * 70) / 255 : 70);
        g_painter->setColor(shadowColor);
        g_painter->drawTexturedRect(m_dest, m_texture, m_src);
        return;
    }

    if (m_flipDirection != 0) {
        Size fboSize(m_dest.width(), m_dest.height());
        g_framebuffers.getTemporaryFrameBuffer()->resize(fboSize);
        g_framebuffers.getTemporaryFrameBuffer()->setSmooth(true);
        g_framebuffers.getTemporaryFrameBuffer()->bind();
        g_painter->clear(Color::alpha);

        // Draw item texture filling the FBO (same as normal path but into FBO)
        g_painter->setColor(m_color);
        g_painter->drawTexturedRect(Rect(0, 0, fboSize), m_texture, m_src);

        g_framebuffers.getTemporaryFrameBuffer()->release();

        // Draw FBO with flip
        g_framebuffers.getTemporaryFrameBuffer()->draw(m_dest, m_flipDirection);
        return;
    }

    g_painter->setColor(m_color);
    g_painter->drawTexturedRect(m_dest, m_texture, m_src);
}

bool DrawQueueItemTexturedRect::cache()
{
    if (m_noCache || m_isShadow)
        return false;
    if (m_dest.size() > m_src.size()) // upscaling may create artifacts
        return false;
    if (!m_texture->canCache())
        return false;

    m_texture->update();
    uint64_t hash = 100 + m_texture->getUniqueId();
    bool drawNow = false;
    Point atlasPos = g_atlas.cache(hash, m_texture->getSize(), drawNow);
    if (atlasPos.x < 0) { return false; } // can't be cached
    if (drawNow) { g_drawCache.bind(); draw(atlasPos); }

    if (!g_drawCache.hasSpace(6))
        return false;

    g_drawCache.addTexturedRect(m_dest, m_src + atlasPos, m_color);
    return true;
}

void DrawQueueItemTexturedRect::draw(const Point& pos)
{
    g_painter->resetColor();
    g_painter->drawTexturedRect(Rect(pos, m_texture->getSize()), m_texture);
}


void DrawQueueItemFramebufferWithShader::draw()
{
    if (!m_queue || m_dest.isEmpty())
        return;

    const Size screenSize = g_painter->getResolution();
    if (!screenSize.isValid())
        return;

    FrameBufferPtr framebuffer = g_framebuffers.getDrawQueueTemporaryFrameBuffer();
    if (!framebuffer)
        return;

    framebuffer->resize(screenSize);
    framebuffer->setSmooth(true);
    framebuffer->bind();
    g_painter->clear(Color::alpha);
    m_queue->draw(DRAW_ALL);
    framebuffer->release();

    PainterShaderProgramPtr shader;
    if (!m_shader.empty()) {
        shader = g_shaders.getShader(m_shader);
        if (shader) {
            // Framebuffers are stored upside down, so the shader reads its
            // fragments with the y axis measured from the bottom: the center
            // has to be given in that same space or the effect would be
            // mirrored vertically on widgets that are not screen centered.
            shader->setCenter(Point(m_dest.center().x, screenSize.height() - m_dest.center().y));
            shader->setOffset(Point(m_dest.width() / 2, m_dest.height() / 2));
            g_painter->setShaderProgram(shader);
        }
    }

    g_painter->resetColor();
    g_painter->drawTexturedRect(m_dest, framebuffer->getTexture(), Rect(m_dest.topLeft(), m_dest.size()));

    if (shader) {
        g_painter->resetShaderProgram();
        g_painter->resetTexture();
    }
}

bool DrawQueueItemFilledRect::cache()
{
    if (!g_drawCache.hasSpace(6)) return false;
    g_drawCache.addRect(m_dest, m_color);
    return true; 
}

void DrawQueueItemClearRect::draw()
{
    g_painter->clearRect(m_color, m_dest);
}

bool DrawQueueItemFillCoords::cache()
{
    int size = m_coordsBuffer.getVertexCount();
    if (!g_drawCache.hasSpace(size))
        return false;

    g_drawCache.addCoords(m_coordsBuffer, m_color);
    return true;
}

void DrawQueueItemText::draw()
{
    g_text.drawText(m_point, m_hash, m_color, m_shadow);
}

void DrawQueueItemTextColored::draw()
{
    g_text.drawColoredText(m_point, m_hash, m_colors, m_shadow);
}

void DrawQueueItemNormalMapped::draw()
{
    if (!m_texture || !m_normalMap) {
        // Fallback: draw without normal mapping
        g_painter->setColor(m_color);
        g_painter->drawTexturedRect(m_dest, m_texture, m_src);
        return;
    }

    // Get the normal mapping shader
    static PainterShaderProgramPtr normalMapShader;
    static bool loggedShaderCreated = false;
    static bool loggedShaderFailed = false;
    if (!normalMapShader) {
        normalMapShader = PainterShaderProgram::create("normalMapShader",
            glslNormalMapVertexShader, glslNormalMapFragmentShader);
        if (normalMapShader && !loggedShaderCreated) {
            g_logger.info("NormalMapShader: compiled successfully");
            loggedShaderCreated = true;
        }
    }
    if (!normalMapShader) {
        if (!loggedShaderFailed) {
            g_logger.warning("NormalMapShader: compilation FAILED, falling back to normal draw");
            loggedShaderFailed = true;
        }
        g_painter->setColor(m_color);
        g_painter->drawTexturedRect(m_dest, m_texture, m_src);
        return;
    }

    // Get light data
    NormalMapLightData& lightData = g_normalMaps.getLightData();

    // Bind normal map shader
    g_painter->setShaderProgram(normalMapShader.get());
    g_painter->setColor(m_color);

    // Set light uniforms
    for (int i = 0; i < MAX_NORMAL_MAP_LIGHTS; ++i) {
        if (i < lightData.lightCount) {
            normalMapShader->setLightPos(i, lightData.lights[i].posX, lightData.lights[i].posY,
                                         lightData.lights[i].radius, lightData.lights[i].intensity);
        } else {
            normalMapShader->setLightPos(i, 0, 0, 0, 0);
        }
    }
    normalMapShader->setAmbientLight(lightData.ambientLight);
    normalMapShader->setSunDirection(lightData.sunDirX, lightData.sunDirY, lightData.sunDirZ);
    normalMapShader->setSunIntensity(lightData.sunIntensity);

    // Bind normal map as second texture (u_Tex1 = texture unit 1).
    // IMPORTANT: switch to GL_TEXTURE1 BEFORE calling update() so that
    // Texture::update()'s internal glBindTexture() targets unit 1 instead
    // of clobbering whatever is on GL_TEXTURE0 (the atlas / sprite texture).
    glActiveTexture(GL_TEXTURE1);
    m_normalMap->update();
    glBindTexture(GL_TEXTURE_2D, m_normalMap->getId());
    glActiveTexture(GL_TEXTURE0);

    // Draw the textured rect with the normal map shader
    g_painter->drawTexturedRect(m_dest, m_texture, m_src);

    // Reset shader and invalidate painter texture cache so the next
    // drawCache() or drawTexturedRect() rebinds the correct texture.
    g_painter->resetShaderProgram();
    g_painter->resetTexture();
}

void DrawQueueItemNormalMapped::draw(const Point& pos)
{
    if (!m_texture || !m_normalMap) {
        g_painter->resetColor();
        g_painter->drawTexturedRect(Rect(pos, m_texture->getSize()), m_texture);
        return;
    }

    // Same as draw() but with calculated position
    Rect dest(pos, m_src.size());
    m_dest = dest;
    draw();
}

void::DrawQueueItemLine::draw()
{
    g_painter->setColor(m_color);
    static std::vector<float> vertices(1024, 0);
    if (vertices.size() < m_points.size())
        vertices.resize(m_points.size());
    int i = 0;
    for (Point& point : m_points) {
        vertices[i++] = point.x;
        vertices[i++] = point.y;
    }
    g_painter->drawLine(vertices, i / 2, m_width);
}

void DrawQueueConditionClip::start(DrawQueue*)
{
    m_prevClip = g_painter->getClipRect();
    g_painter->setClipRect(m_rect);
}

void DrawQueueConditionClip::end(DrawQueue*)
{
    g_painter->setClipRect(m_prevClip);
}

void DrawQueueConditionRotation::start(DrawQueue*)
{
    g_painter->pushTransformMatrix();
    g_painter->rotate(m_center, m_angle);
}

void DrawQueueConditionRotation::end(DrawQueue*)
{
    g_painter->popTransformMatrix();
}

void DrawQueueConditionMark::start(DrawQueue*)
{
    // nothing
}

void DrawQueueConditionMark::end(DrawQueue* queue)
{
    g_painter->setDrawColorOnTextureShaderProgram();
    g_painter->setColor(m_color);
    for (size_t i = m_start; i < m_end; ++i) {
        DrawQueueItemTexturedRect* texture = dynamic_cast<DrawQueueItemTexturedRect*>(queue->m_queue[i]);
        if (texture)
            g_painter->drawTexturedRect(texture->m_dest, texture->m_texture, texture->m_src);
    }
    g_painter->resetShaderProgram();
}

void DrawQueue::setFrameBuffer(const Rect& dest, const Size& size, const Rect& src)
{
    m_useFrameBuffer = true;
    m_frameBufferSize = size;
    m_frameBufferDest = dest;
    m_frameBufferSrc = src;
    size_t max_size = std::max(m_frameBufferSize.width(), m_frameBufferSize.height());
    while(max_size > 2048u) {
        max_size /= 2;
        m_scaling /= 2.f;
    }
    if (m_scaling < 0.99f) {
        m_frameBufferSize = Size(2048, 2048);
        m_frameBufferSrc = m_frameBufferSrc * m_scaling;
    }
}

void DrawQueue::addText(BitmapFontPtr font, const std::string& text, const Rect& screenCoords, Fw::AlignmentFlag align, const Color& color, bool shadow)
{
    if (!font || text.empty()) return;
    uint64_t hash = g_text.addText(font, text, screenCoords.size(), align);
    m_queue.push_back(new DrawQueueItemText(screenCoords.topLeft(), font->getTexture(), hash, color, shadow));
}

void DrawQueue::addColoredText(BitmapFontPtr font, const std::string& text, const Rect& screenCoords, Fw::AlignmentFlag align, const std::vector<std::pair<int, Color>>& colors, bool shadow)
{
    if (!font || text.empty()) return;
    uint64_t hash = g_text.addText(font, text, screenCoords.size(), align);
    m_queue.push_back(new DrawQueueItemTextColored(screenCoords.topLeft(), font->getTexture(), hash, colors, shadow));
}

void DrawQueue::correctOutfit(const Rect& dest, int fromPos, bool oldScaling)
{
    std::vector<Rect*> rects;
    if (!oldScaling) {
        bool center = false;
        int centerX = 0;
        int centerY = 0;
        for (size_t i = fromPos; i < m_queue.size(); ++i) {
            if (DrawQueueItemOutfit* texture = dynamic_cast<DrawQueueItemOutfit*>(m_queue[i])) {
                rects.push_back(&texture->m_dest);
                if (!center) {
                    center = texture->m_doCenter;
                }

                if (texture->m_doCenter) {
                    centerX = std::max<int>(centerX, texture->m_dest.center().x);
                    centerY = std::max<int>(centerY, texture->m_dest.center().y);
                }
            }
            else if (DrawQueueItemOutfitWithShader* texture = dynamic_cast<DrawQueueItemOutfitWithShader*>(m_queue[i])) {
                rects.push_back(&texture->m_dest);
                if (!center) {
                    center = texture->m_doCenter;
                }

                if (texture->m_doCenter) {
                    centerX = std::max<int>(centerX, texture->m_dest.center().x);
                }
            }
            else if (DrawQueueItemTexturedRect* texture = dynamic_cast<DrawQueueItemTexturedRect*>(m_queue[i])) {
                rects.push_back(&texture->m_dest);
            }
        }

        int x1 = -g_sprites.spriteSize(), y1 = -g_sprites.spriteSize(), x2 = g_sprites.spriteSize(), y2 = g_sprites.spriteSize();
        float scale = std::min<float>((float)dest.height() / (y2 - y1), (float)dest.width() / (x2 - x1));
        for (auto& rect : rects) {
            int x = rect->left() - x1 - centerX, y = rect->top() - y1 - centerY; // offset
            *rect = Rect(dest.left() + x * scale, dest.top() + y * scale, rect->size() * scale);
        }
    }
    else {
        for (size_t i = fromPos; i < m_queue.size(); ++i) {
            if (DrawQueueItemTexturedRect* texture = dynamic_cast<DrawQueueItemTexturedRect*>(m_queue[i]))
                rects.push_back(&texture->m_dest);
        }

        int x1 = 0, y1 = 1, x2 = 0, y2 = 0;
        for (auto& rect : rects) {
            x1 = std::min<int>(x1, rect->left());
            y1 = std::min<int>(y1, rect->top());
            x2 = std::max<int>(x2, rect->right());
            y2 = std::max<int>(y2, rect->bottom());
        }
        if (x1 == x2 || y1 == y2) return;

        float scale = std::min<float>((float)dest.height() / (y2 - y1), (float)dest.width() / (x2 - x1));
        for (auto& rect : rects) {
            int x = rect->left() - x1, y = rect->top() - y1; // offset
            *rect = Rect(dest.left() + x * scale, dest.top() + y * scale, rect->size() * scale);
        }
    }
}

void DrawQueue::scaleOutfit(int fromPos, float scale)
{
    std::vector<Rect*> rects;
    for (size_t i = fromPos; i < m_queue.size(); ++i) {
        if (DrawQueueItemTexturedRect* texture = dynamic_cast<DrawQueueItemTexturedRect*>(m_queue[i]))
            rects.push_back(&texture->m_dest);
    }
    if (rects.empty()) return;

    float cx = 0, cy = 0;
    for (auto* r : rects) { cx += r->center().x; cy += r->center().y; }
    cx /= rects.size(); cy /= rects.size();

    for (auto* r : rects) {
        float dx = r->center().x - cx, dy = r->center().y - cy;
        *r = Rect(cx + dx * scale - r->width() * scale / 2.0f,
                  cy + dy * scale - r->height() * scale / 2.0f,
                  r->width() * scale, r->height() * scale);
    }
}

void DrawQueue::draw(DrawType drawType)
{
    size_t start = 0;
    size_t end = m_queue.size();
    if (drawType == DRAW_BEFORE_MAP) {
        end = mapPosition;
    } else if (drawType == DRAW_AFTER_MAP) {
        start = mapPosition;
    }

    std::sort(m_conditions.begin(), m_conditions.end(), [](const DrawQueueCondition* a, const DrawQueueCondition* b) -> bool {
        return a->m_start == b->m_start ? a->m_end < b->m_end : a->m_start < b->m_start;
    });

    Size originalResolution = g_painter->getResolution();
    if (m_scaling > 0.f && m_scaling < 0.99f) {
        Size resolution = originalResolution * (1.f / m_scaling);
        Matrix3 projectionMatrix = { 
            2.0f / resolution.width(),  0.0f,                      0.0f,
            0.0f,                    -2.0f / resolution.height(),  0.0f,
            -1.0f,                     1.0f,                      1.0f 
        };
        g_painter->setProjectionMatrix(projectionMatrix);
    }

    auto condition = m_conditions.begin();
    std::stack<DrawQueueCondition*> activeConditions;
    // skip conditions
    while (condition != m_conditions.end() && (*condition)->m_end <= start)
        ++condition;
    // execute conditions & draw
    for (size_t i = start; i < end; ++i) {
        while (!activeConditions.empty() && activeConditions.top()->m_end <= i) {
            g_drawCache.draw();
            activeConditions.top()->end(this);
            activeConditions.pop();
        }
        while (condition != m_conditions.end() && (*condition)->m_start <= i) {
            g_drawCache.draw();
            (*condition)->start(this);
            activeConditions.push(*condition);
            ++condition;
        }

        if (!m_queue[i]->cache()) {
            g_drawCache.draw();
            if (!m_queue[i]->cache()) { // try to cache again, now g_drawCache should be empty, maybe there's new space
                m_queue[i]->draw();
            }
        }
        if (g_drawCache.getSize() >= g_drawCache.HALF_MAX_SIZE) {
            g_drawCache.draw();
        }
    }
    g_drawCache.draw();
    // end all actibe conditions
    while (!activeConditions.empty()) {
        activeConditions.top()->end(this);
        activeConditions.pop();
    }

    g_painter->setResolution(originalResolution);
    g_painter->resetState();
    g_graphics.checkForError(__FUNCTION__, __FILE__, __LINE__);
}
