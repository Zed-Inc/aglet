## GLFW windowing backend.
## This backend relies on GLFW to do all the hard work of creating and managing
## the window. For now, this is pretty much the backend you want to use in
## production. Custom X11 and Win32 backends will be implemented in the future.
##
## **Caveat:** This backend uses *a ton* of global state! If you're using
## threads or loading plugins dynamically via DLLs, using this module in a
## thread other than the main one or in a DLL is a *very bad idea*.
## Apart from this, some procedures like ``swapInterval=`` will set the given
## state globally, which is probably not what you want.

import std/options
import std/unicode

import glm/vec

import ../input
import ../lib/glfw3
import ../state
import ../window

type
  GlfwErrorCode* = enum
    gecNoError
    gecNotInitialized = 0x10001
    gecNoCurrentCtx
    gecInvalidEnum
    gecInvalidValue
    gecOutOfMem
    gecApiUnavailable
    gecVersionUnavailable
    gecPlatformError
    gecFormatUnavailable
    gecNoWindowCtx
  GlfwWindowError* = object of CatchableError
    code: GlfwErrorCode
  WindowGlfw* = ref object of Window
    handle: ptr GLFWwindow
    processEvent: InputProc

proc checkGlfwError() =
  var cmessage: cstring
  let errCode = glfwGetError(cast[cstringArray](addr cmessage)).GlfwErrorCode
  if errCode != gecNoError:
    let message = $cmessage
    var err = (ref GlfwWindowError)(code: errCode, msg: message)
    raise err

proc implWindow(win: WindowGlfw) =
  template wing: WindowGlfw = win.WindowGlfw

  win.pollEventsImpl = proc (win: Window, processEvent: InputProc) {.nosinks.} =
    wing.processEvent = processEvent
    # XXX: hopefully this is enough to make polling *not* be global, but I'll
    # have to confirm this
    wing.IMPL_makeCurrent()
    glfwPollEvents()

  win.waitEventsImpl = proc (win: Window, processEvent: InputProc,
                             timeout: float) {.nosinks.} =
    wing.processEvent = processEvent
    wing.IMPL_makeCurrent()
    glfwWaitEventsTimeout(timeout.cdouble)
    glfwWaitEvents()

  win.pollMouseImpl = proc (win: Window): Vec2f =
    var x, y: cdouble
    glfwGetCursorPos(wing.handle, addr x, addr y)
    result = vec2f(x, y)

  win.makeCurrentImpl = proc (win: Window) =
    glfwMakeContextCurrent(wing.handle)

  win.getProcAddrImpl = proc (name: string): pointer =
    win.IMPL_makeCurrent()
    result = cast[pointer](glfwGetProcAddress(name))

  win.setSwapIntervalImpl = proc (win: Window, interval: int) =
    wing.IMPL_makeCurrent()
    glfwSwapInterval(interval.cint)

  win.swapBuffersImpl = proc (win: Window) =
    glfwSwapBuffers(wing.handle)

  win.setCloseRequestedImpl = proc (win: Window, close: bool) =
    glfwSetWindowShouldClose(wing.handle, close.cint)

  win.closeRequestedImpl = proc (win: Window): bool =
    result = glfwWindowShouldClose(wing.handle).bool

  win.iconifyImpl = proc (win: Window) = glfwIconifyWindow(wing.handle)
  win.maximizeImpl = proc (win: Window) = glfwMaximizeWindow(wing.handle)
  win.restoreImpl = proc (win: Window) = glfwRestoreWindow(wing.handle)
  win.showImpl = proc (win: Window) = glfwShowWindow(wing.handle)
  win.hideImpl = proc (win: Window) = glfwHideWindow(wing.handle)

  win.iconifiedImpl = proc (win: Window): bool =
    glfwGetWindowAttrib(wing.handle, GLFW_ICONIFIED).bool
  win.maximizedImpl = proc (win: Window): bool =
    glfwGetWindowAttrib(wing.handle, GLFW_MAXIMIZED).bool
  win.visibleImpl = proc (win: Window): bool =
    glfwGetWindowAttrib(wing.handle, GLFW_VISIBLE).bool

  win.getSizeImpl = proc (win: Window, w, h: var int) =
    var cw, ch: cint
    glfwGetWindowSize(wing.handle, addr cw, addr ch)
    w = cw
    h = ch

  win.setSizeImpl = proc (win: Window, w, h: int) =
    glfwSetWindowSize(wing.handle, w.cint, h.cint)

  win.getFramebufferSizeImpl = proc (win: Window, w, h: var int) =
    var cw, ch: cint
    glfwGetFramebufferSize(wing.handle, addr cw, addr ch)
    w = cw
    h = ch

  win.getContentScaleImpl = proc (win: Window, x, y: var float) =
    var cx, cy: cfloat
    glfwGetWindowContentScale(wing.handle, addr cx, addr cy)
    x = cx
    y = cy

  win.setSizeLimitsImpl = proc (win: Window, min, max: Option[Vec2i]) =
    let
      xmin = if min.isSome: min.get.x else: GLFW_DONT_CARE
      ymin = if min.isSome: min.get.y else: GLFW_DONT_CARE
      xmax = if max.isSome: max.get.x else: GLFW_DONT_CARE
      ymax = if max.isSome: max.get.y else: GLFW_DONT_CARE
    glfwSetWindowSizeLimits(wing.handle, xmin, ymin, xmax, ymax)

  win.setAspectRatioImpl = proc (win: Window, num, den: int) =
    glfwSetWindowAspectRatio(wing.handle, num.cint, den.cint)

  win.resetAspectRatioImpl = proc (win: Window) =
    glfwSetWindowAspectRatio(wing.handle, GLFW_DONT_CARE, GLFW_DONT_CARE)

  win.setTitleImpl = proc (win: Window, title: string) =
    glfwSetWindowTitle(wing.handle, title)

  win.setPositionImpl = proc (win: Window, x, y: int) =
    glfwSetWindowPos(wing.handle, x.cint, y.cint)

  win.getPositionImpl = proc (win: Window, x, y: var int) =
    var cx, cy: cint
    glfwGetWindowPos(wing.handle, addr cx, addr cy)
    x = cx
    y = cy

proc toModKeySet(bits: cint): set[ModKey] =
  if (bits and GLFW_MOD_SHIFT) != 0: result.incl(mkShift)
  if (bits and GLFW_MOD_CONTROL) != 0: result.incl(mkCtrl)
  if (bits and GLFW_MOD_ALT) != 0: result.incl(mkAlt)
  if (bits and GLFW_MOD_SUPER) != 0: result.incl(mkSuper)
  if (bits and GLFW_MOD_CAPS_LOCK) != 0: result.incl(mkCapsLock)
  if (bits and GLFW_MOD_NUM_LOCK) != 0: result.incl(mkNumLock)

proc eventHooks(win: WindowGlfw) =
  template wing: WindowGlfw = cast[WindowGlfw](glfwGetWindowUserPointer(win))

  glfwSetWindowPosCallback(win.handle) do (win: ptr GLFWwindow,
                                           x, y: cint) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekWindowMove,
                                 windowPos: vec2i(x, y)))

  glfwSetWindowSizeCallback(win.handle) do (win: ptr GLFWwindow,
                                            width, height: cint) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekWindowResize,
                                 size: vec2i(width, height)))

  glfwSetWindowCloseCallback(win.handle) do (win: ptr GLFWwindow) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekWindowClose))

  glfwSetWindowRefreshCallback(win.handle) do (win: ptr GLFWwindow) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekWindowRedraw))

  glfwSetWindowFocusCallback(win.handle) do (win: ptr GLFWwindow,
                                             focused: cint) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekWindowFocus, focused: focused.bool))

  glfwSetWindowIconifyCallback(win.handle) do (win: ptr GLFWwindow,
                                               iconified: cint) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekWindowIconify,
                                 iconified: iconified.bool))

  glfwSetWindowMaximizeCallback(win.handle) do (win: ptr GLFWwindow,
                                                maximized: cint) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekWindowMaximize,
                                 maximized: maximized.bool))

  glfwSetFramebufferSizeCallback(win.handle) do (win: ptr GLFWwindow,
                                                 width, height: cint) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekWindowFrameResize,
                                 size: vec2i(width, height)))

  glfwSetWindowContentScaleCallback(win.handle) do (win: ptr GLFWwindow,
                                                    x, y: cfloat) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekWindowScale,
                                 scale: vec2f(x, y)))

  glfwSetKeyCallback(win.handle) do (win: ptr GLFWwindow, key, scancode, action,
                                     mods: cint) {.cdecl.}:
    let kind =
      case action
      of GLFW_PRESS: iekKeyPress
      of GLFW_REPEAT: iekKeyRepeat
      else: iekKeyRelease
    var event = InputEvent(kind: kind)
    event.key = key.Key
    event.scancode = scancode.int
    event.kMods = mods.toModKeySet
    wing.processEvent(event)

  glfwSetCharCallback(win.handle) do (win: ptr GLFWwindow,
                                      codepoint: cuint) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekKeyChar, rune: codepoint.Rune))

  glfwSetMouseButtonCallback(win.handle) do (win: ptr GLFWwindow,
                                             button, action,
                                             mods: cint) {.cdecl.}:
    let kind =
      if action == GLFW_PRESS: iekMousePress
      else: iekMouseRelease
    var event = InputEvent(kind: kind)
    event.button = button.MouseButton
    event.bMods = mods.toModKeySet
    wing.processEvent(event)

  glfwSetCursorPosCallback(win.handle) do (win: ptr GLFWwindow,
                                           x, y: cdouble) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekMouseMove,
                                 mousePos: vec2f(x, y)))

  glfwSetCursorEnterCallback(win.handle) do (win: ptr GLFWwindow,
                                             entered: cint) {.cdecl.}:
    let kind =
      if entered.bool: iekMouseEnter
      else: iekMouseLeave
    wing.processEvent(InputEvent(kind: kind))

  glfwSetScrollCallback(win.handle) do (win: ptr GLFWwindow,
                                        x, y: cdouble) {.cdecl.}:
    wing.processEvent(InputEvent(kind: iekMouseScroll,
                                 scrollPos: vec2f(x, y)))

  glfwSetDropCallback(win.handle) do (win: ptr GLFWwindow,
                                      count: cint,
                                      paths: cstringArray) {.cdecl.}:
    let spaths = cstringArrayToSeq(paths, count.Natural)
    wing.processEvent(InputEvent(kind: iekFileDrop,
                                 filePaths: spaths))

proc newWindowGlfw*(agl: Aglet, width, height: int, title: string,
                    hints = DefaultWindowHints): WindowGlfw =
  ## Creates a new window using the GLFW backend, with the specified size,
  ## title, passing the given hints to GLFW.

  # initialize GLFW once
  once:
    if not glfwInit().bool:
      checkGlfwError()

  # destroy the window in the finalizer
  new(result) do (win: WindowGlfw):
    glfwDestroyWindow(win.handle)

  # makeCurrent has to work, of course
  result.agl = agl

  # set all the hints
  glfwWindowHint(GLFW_RESIZABLE, hints.resizable.cint)
  glfwWindowHint(GLFW_VISIBLE, hints.visible.cint)
  glfwWindowHint(GLFW_DECORATED, hints.decorated.cint)
  glfwWindowHint(GLFW_FOCUSED, hints.focused.cint)
  glfwWindowHint(GLFW_FLOATING, hints.floating.cint)
  glfwWindowHint(GLFW_MAXIMIZED, hints.maximized.cint)
  glfwWindowHint(GLFW_TRANSPARENT_FRAMEBUFFER, hints.transparent.cint)
  glfwWindowHint(GLFW_SCALE_TO_MONITOR, hints.scaleToDpi.cint)

  glfwWindowHint(GLFW_RED_BITS, hints.colorBits.red.cint)
  glfwWindowHint(GLFW_GREEN_BITS, hints.colorBits.green.cint)
  glfwWindowHint(GLFW_BLUE_BITS, hints.colorBits.blue.cint)
  glfwWindowHint(GLFW_ALPHA_BITS, hints.colorBits.alpha.cint)
  glfwWindowHint(GLFW_DEPTH_BITS, hints.depthBits.cint)
  glfwWindowHint(GLFW_STENCIL_BITS, hints.stencilBits.cint)
  glfwWindowHint(GLFW_STEREO, hints.stereoscopic.cint)
  glfwWindowHint(GLFW_SAMPLES, hints.msaaSamples.cint)

  glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_API)
  when not defined(windows) and not defined(aglGlfwUseNativeGl):
    # XXX: verify compatibility on older drivers/GPUs on linux
    # I've read that EGL is faster than GLX because it has less indirections,
    # but I'm not sure about the compatibility across different systems
    glfwWindowHint(GLFW_CONTEXT_CREATION_API, GLFW_EGL_CONTEXT_API)
  else:
    glfwWindowHint(GLFW_CONTEXT_CREATION_API, GLFW_NATIVE_CONTEXT_API)
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, hints.glVersion.major.cint)
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, hints.glVersion.minor.cint)
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE)
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, hints.debugContext.cint)

  # create the actual window
  result.handle = glfwCreateWindow(width.cint, height.cint, "", nil, nil)
  checkGlfwError()

  glfwSetWindowUserPointer(result.handle, cast[pointer](result))

  result.implWindow()
  result.eventHooks()

  result.title = title

  result.IMPL_loadGl()
