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

#include "event.h"
#include <framework/core/logger.h>
#include <framework/core/clock.h>
#include <framework/stdext/string.h>

Event::Event(const std::string& function, const std::function<void()>& callback, bool botSafe) :
    m_function(function),
    m_callback(callback),
    m_canceled(false),
    m_executed(false),
    m_botSafe(botSafe)
{
}

Event::~Event()
{
    // assure that we lost callback refs
    //VALIDATE(m_callback == nullptr);
}

// Shared by Event and ScheduledEvent: reports an uncaught callback exception
// without flooding the log. Logging itself schedules another event (Logger::log),
// so logging every exception from a failing callback would loop forever (a
// 246k-line flood was observed). At most one report per 2 seconds is printed.
// Atomic: Event::execute runs on both the graphics and the dispatcher thread.
void reportEventException(const std::string& msg)
{
    static std::atomic<uint64_t> lastReport = 0;
    uint64 now = g_clock.millis();
    uint64 last = lastReport.load();
    if (now - last >= 2000 || last == 0) {
        if (lastReport.compare_exchange_strong(last, now))
            g_logger.error(msg);
    }
}

void Event::execute()
{
    if(!m_canceled && !m_executed && m_callback) {
        // Guard every dispatcher event so that a single rogue callback (a
        // broken sprite throwing inside the texture preloader, a bad_alloc,
        // etc.) can never std::terminate the whole client silently. This is
        // the last line of defence: the error is logged and the app lives on.
        try {
            m_callback();
        } catch (const std::exception& e) {
            reportEventException(stdext::format("Uncaught exception in event '%s': %s", m_function, e.what()));
        } catch (...) {
            reportEventException(stdext::format("Uncaught unknown exception in event '%s'", m_function));
        }
        m_executed = true;
    }

    // reset callback to free object refs
    m_callback = nullptr;
}

void Event::cancel()
{
    m_canceled = true;
    m_callback = nullptr;
}
