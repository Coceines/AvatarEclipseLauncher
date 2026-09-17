/*
 * Esse software e suas funcionalidades foram criados por Sirius, me procure no
 * TibiaDevs ou no discord, meu usuario é __Kenai__ Se você nao comprou esse
 * sistema com Sirius, você pode ter caido em um golpe ou uma revenda nao
 * autorizada por mim. Obrigado por ter comprado o sistema e espero que faça bom
 * proveito.
 */

#pragma once

#ifdef TOGGLE_GAMEPAD
; // Safety semicolon for unity builds
#include <functional>
#include <string>

#define SDL_MAIN_HANDLED
#include <SDL2/SDL.h>
#include <framework/luaengine/luainterface.h>

// Dead-zone threshold for analog sticks (SDL axis range: -32768 to 32767)
static constexpr int16_t CONTROLLER_AXIS_DEADZONE = 8000;

/**
 * ControllerManager
 *
 * Manages a single SDL2 GameController device.
 */
class ControllerManager {
public:
  ControllerManager() = default;
  ~ControllerManager() = default;

  // Lifecycle
  void init();
  void poll();
  void terminate();

  // Status
  bool isConnected();
  std::string getControllerName();

  // Lua callback registration
  void setButtonCallback(const std::function<void(std::string, bool)> &fn) {
    m_buttonCallback = fn;
  }
  void setAxisCallback(const std::function<void(std::string, float)> &fn) {
    m_axisCallback = fn;
  }
  void setConnectCallback(const std::function<void(bool)> &fn) {
    m_connectCallback = fn;
  }

private:
  // Helpers
  void tryOpenFirstController();
  void closeController();
  void dispatchButton(SDL_GameControllerButton button, bool pressed);
  void dispatchAxis(SDL_GameControllerAxis axis, int16_t rawValue);

  // State
  SDL_GameController *m_controller{nullptr};
  SDL_JoystickID m_instanceId{-1};

  std::function<void(std::string, bool)> m_buttonCallback;
  std::function<void(std::string, float)> m_axisCallback;
  std::function<void(bool)> m_connectCallback;
};

extern ControllerManager g_controller;

#endif // TOGGLE_GAMEPAD
