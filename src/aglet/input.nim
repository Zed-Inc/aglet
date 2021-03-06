import unicode

import glm/vec

type
  Key* = enum  # indices taken directly from GLFW
    keyUnknown = -1
    keySpace = 32
    keyApos = 39
    keyComma = 44, keyMinus, keyPeriod, keySlash
    key0 = 48, key1, key2, key3, key4, key5, key6, key7, key8, key9
    keySemi = 59
    keyEqual
    keyA = 65, keyB, keyC, keyD, keyE, keyF, keyG, keyH, keyI, keyJ, keyK, keyL,
    keyM, keyN, keyO, keyP, keyQ, keyR, keyS, keyT, keyU, keyV, keyW, keyX,
    keyY, keyZ
    keyLBracket = 91, keyBackslash, keyRBracket
    keyGraveAcc = 96
    keyWorld1 = 161, keyWorld2
    keyEsc = 256, keyEnter, keyTab, keyBackspace, keyInsert, keyDelete
    keyRight, keyLeft, keyDown, keyUp
    keyPgUp, keyPgDown, keyHome, keyEnd
    keyCapsLock, keyScrollLock, keyNumLock
    keyPrintScreen, keyPause
    keyF1 = 290, keyF2, keyF3, keyF4, keyF5, keyF6, keyF7, keyF8, keyF9, keyF10,
    keyF11, keyF12, keyF13, keyF14, keyF15, keyF16, keyF17, keyF18, keyF19,
    keyF20, keyF21, keyF22, keyF23, keyF24, keyF25
    keyKp0, keyKp1, keyKp2, keyKp3, keyKp4, keyKp5, keyKp6, keyKp7, keyKp8,
    keyKp9, keyKpDot, keyKpDiv, keyKpMult, keyKpSub, keyKpAdd, keyKpEnter,
    keyKpEqual
    keyLShift = 340, keyLCtrl, keyLAlt, keyLSuper
    keyRShift, keyRCtrl, keyRAlt, keyRSuper
    keyMenu
  ModKey* = enum
    mkShift, mkCtrl, mkAlt, mkSuper
    mkCapsLock, mkNumLock
  MouseButton* = enum
    mb1 = 0, mb2, mb3, mb4, mb5, mb6, mb7, mb8
  InputEventKind* = enum
    iekWindowMove         ## the window has been moved
    iekWindowResize       ## the window has been resized
    iekWindowClose        ## window close request
    iekWindowRedraw       ## the window needs to be redrawn
    iekWindowFocus        ## the window's focus has been changed
    iekWindowIconify      ## the window has been (un)iconified
    iekWindowMaximize     ## the window has been (un)maximized
    iekWindowFrameResize  ## the window's framebuffer has been resized
    iekWindowScale        ## the window's content scale has changed
    iekKeyPress           ## a key has been pressed
    iekKeyRepeat          ## wm key repeat
    iekKeyRelease         ## a key has been released
    iekKeyChar            ## a character has been typed
    iekMousePress         ## a mouse button has been pressed
    iekMouseRelease       ## a mouse button has been released
    iekMouseMove          ## the mouse cursor has been moved
    iekMouseEnter         ## the mouse cursor entered the window
    iekMouseLeave         ## the mouse cursor left the window
    iekMouseScroll        ## the scroll wheel has been moved
    iekFileDrop           ## files have been dropped onto the window
  InputEvent* = object
    case kind*: InputEventKind
    of iekWindowMove:
      windowPos*: Vec2i
    of iekWindowResize, iekWindowFrameResize:
      size*: Vec2i
    of iekWindowClose: discard
    of iekWindowRedraw: discard
    of iekWindowFocus:
      focused*: bool
    of iekWindowIconify:
      iconified*: bool
    of iekWindowMaximize:
      maximized*: bool
    of iekWindowScale:
      scale*: Vec2f
    of iekKeyPress..iekKeyRelease:
      key*: Key            ## the pressed key
      scancode*: int
        ## the pressed key's scancode
        ## (keyboard layout-independent number, useful for saving keys)
      kMods*: set[ModKey]  ## any modifier keys
    of iekKeyChar:
      rune*: Rune  ## the UTF-8 character that was typed
    of iekMousePress, iekMouseRelease:
      button*: MouseButton  ## the pressed mouse button
      bMods*: set[ModKey]   ## any modifier keys
    of iekMouseMove:
      mousePos*: Vec2f  ## the new mouse position
    of iekMouseEnter, iekMouseLeave: discard
    of iekMouseScroll:
      scrollPos*: Vec2f
    of iekFileDrop:
      filePaths*: seq[string]
  InputProc* = proc (ev: InputEvent) ## input event handler

const
  mbLeft* = mb1
    ## The left mouse button. Using these constants is
    ## preferred over using ``mb1..3`` directly to aid readability.
  mbRight* = mb2   ## The right mouse button.
  mbMiddle* = mb3  ## The middle mouse button.
