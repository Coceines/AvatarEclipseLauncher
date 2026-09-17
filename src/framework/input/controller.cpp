/*
 * Esse software e suas funcionalidades foram criados por Sirius, me procure no
 * TibiaDevs ou no discord, meu usuario é __Kenai__ Se você nao comprou esse
 * sistema com Sirius, você pode ter caido em um golpe ou uma revenda nao
 * autorizada por mim. Obrigado por ter comprado o sistema e espero que faça bom
 * proveito.
 */

#ifdef TOGGLE_GAMEPAD

#include "controller.h"
#include <framework/core/logger.h>

// Global singleton instance
ControllerManager g_controller;

void ControllerManager::init() {
  if (SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER | SDL_INIT_JOYSTICK) < 0) {
    return;
  }

  SDL_GameControllerEventState(SDL_ENABLE);
  SDL_JoystickEventState(SDL_ENABLE);


  tryOpenFirstController();
}

void ControllerManager::poll() {
  SDL_PumpEvents();

  SDL_Event events[32];
  const int count =
      SDL_PeepEvents(events, 32, SDL_GETEVENT, SDL_CONTROLLERAXISMOTION,
                     SDL_CONTROLLERDEVICEREMAPPED);

  for (int i = 0; i < count; ++i) {
    const SDL_Event &e = events[i];

    switch (e.type) {
    case SDL_CONTROLLERDEVICEADDED: {
      if (!m_controller) {
        m_controller = SDL_GameControllerOpen(e.cdevice.which);
        if (m_controller) {
          m_instanceId = SDL_JoystickInstanceID(
              SDL_GameControllerGetJoystick(m_controller));
          if (m_connectCallback) {
            m_connectCallback(true);
          }
        }
      }
      break;
    }

    case SDL_CONTROLLERDEVICEREMOVED: {
      if (m_controller && e.cdevice.which == m_instanceId) {
        closeController();
        if (m_connectCallback) {
          m_connectCallback(false);
        }
      }
      break;
    }

    case SDL_CONTROLLERBUTTONDOWN: {
      if (e.cbutton.which == m_instanceId) {
        dispatchButton(static_cast<SDL_GameControllerButton>(e.cbutton.button),
                       true);
      }
      break;
    }

    case SDL_CONTROLLERBUTTONUP: {
      if (e.cbutton.which == m_instanceId) {
        dispatchButton(static_cast<SDL_GameControllerButton>(e.cbutton.button),
                       false);
      }
      break;
    }

    case SDL_CONTROLLERAXISMOTION: {
      if (e.caxis.which == m_instanceId) {
        dispatchAxis(static_cast<SDL_GameControllerAxis>(e.caxis.axis),
                     e.caxis.value);
      }
      break;
    }

    default:
      break;
    }
  }
}

void ControllerManager::terminate() {
  closeController();
  SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);
}

bool ControllerManager::isConnected() { return (m_controller != nullptr); }

std::string ControllerManager::getControllerName() {
  if (!m_controller) {
    return "None";
  }
  const char *name = SDL_GameControllerName(m_controller);
  return (name ? name : "Unknown Controller");
}

void ControllerManager::tryOpenFirstController() {
  const int numJoysticks = SDL_NumJoysticks();

  for (int i = 0; i < numJoysticks; ++i) {
    if (SDL_IsGameController(i)) {
      m_controller = SDL_GameControllerOpen(i);
      if (m_controller) {
        m_instanceId =
            SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(m_controller));
        return;
      }
    }
  }
}

void ControllerManager::closeController() {
  if (m_controller) {
    SDL_GameControllerClose(m_controller);
    m_controller = nullptr;
    m_instanceId = -1;
  }
}

void ControllerManager::dispatchButton(SDL_GameControllerButton button,
                                       bool pressed) {
  if (!m_buttonCallback)
    return;

  const char *name = SDL_GameControllerGetStringForButton(button);
  if (!name)
    return;

  m_buttonCallback(std::string(name), pressed);
}

void ControllerManager::dispatchAxis(SDL_GameControllerAxis axis,
                                     int16_t rawValue) {
  if (!m_axisCallback)
    return;

  const char *name = SDL_GameControllerGetStringForAxis(axis);
  if (!name)
    return;

  float normalised = 0.0f;
  if (std::abs(rawValue) > CONTROLLER_AXIS_DEADZONE) {
    normalised = rawValue > 0 ? static_cast<float>(rawValue) / 32767.0f
                              : static_cast<float>(rawValue) / 32768.0f;
  }

  m_axisCallback(std::string(name), normalised);
}

#endif // TOGGLE_GAMEPAD
