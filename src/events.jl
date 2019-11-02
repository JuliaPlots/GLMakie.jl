
"""
Throwing an error in a c callback seems to lead to undefined behaviour
"""
macro csafe(func)
    func_body = func.args[2]
    safe_body = quote
        try
            $func_body
        catch e
            println(stderr, "Error in c callback: ")
            Base.showerror(stderr, e)
            # TODO is it fine to call catch_backtrace here?
            Base.show_backtrace(stderr, Base.catch_backtrace())
        end
    end
    func.args[2] = safe_body
    return esc(func)
end

function addbuttons(scene::Scene, name, button, action, ::Type{ButtonEnum}) where ButtonEnum
    event = getfield(scene.events, name)
    set = event[]
    if button != GLFW.KEY_UNKNOWN
        button_enum = ButtonEnum(Int(button))
        if action == GLFW.PRESS
            if ~(button_enum in set)
                push!(set, button_enum)
                event[] = set # trigger setfield event!
            end
        elseif action == GLFW.RELEASE
            if button_enum in set
                delete!(set, button_enum)
                event[] = set # trigger setfield event!
            end
        elseif action == GLFW.REPEAT
            # nothing needs to be done, besides returning the same set of keys
        else
            error("Unrecognized enum value for GLFW button press action: $action")
        end
    end
    return
end

"""
Returns a signal, which is true as long as the window is open.
returns `Node{Bool}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#gaade9264e79fae52bdb78e2df11ee8d6a)
"""
function window_open(scene::Scene, window::GLFW.Window)
    event = scene.events.window_open
    @csafe(function windowclose(win)
        event[] = false
    end)
    disconnect!(window, window_open)
    event[] = isopen(window)
    GLFW.SetWindowCloseCallback(window, windowclose)
end

import AbstractPlotting: disconnect!

function disconnect!(window::GLFW.Window, ::typeof(window_open))
    GLFW.SetWindowCloseCallback(window, nothing)
end

function window_position(window::GLFW.Window)
    xy = GLFW.GetWindowPos(window)
    (xy.x, xy.y)
end
function window_area(scene::Scene, window)
    event = scene.events.window_area
    dpievent = scene.events.window_dpi
    @csafe function windowposition(window, x::Cint, y::Cint)
        rect = event[]
        if minimum(rect) != Vec(x, y)
            event[] = IRect(x, y, framebuffer_size(window))
        end
    end
    @csafe function windowsize(window, w::Cint, h::Cint)
        rect = event[]
        if Vec(w, h) != widths(rect)
            monitor = GLFW.GetPrimaryMonitor()
            props = MonitorProperties(monitor)
            # dpi of a monitor should be the same in x y direction.
            # if not, minimum seems to be a fair default
            dpievent[] = minimum(props.dpi)
            event[] = IRect(minimum(rect), w, h)
        end
    end
    disconnect!(window, window_area)
    monitor = GLFW.GetPrimaryMonitor()
    props = MonitorProperties(monitor)
    dpievent[] = minimum(props.dpi)
    GLFW.SetFramebufferSizeCallback(window, windowsize)
    # TODO put back window position, but right now it makes more trouble than it helps#
    # GLFW.SetWindowPosCallback(window, windowposition)
    return
end

function disconnect!(window::GLFW.Window, ::typeof(window_area))
    GLFW.SetWindowPosCallback(window, nothing)
    GLFW.SetFramebufferSizeCallback(window, nothing)
end


"""
Registers a callback for the mouse buttons + modifiers
returns `Node{NTuple{4, Int}}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function mouse_buttons(scene::Scene, window::GLFW.Window)
    event = scene.events.mousebuttons
    @csafe function mousebuttons(window, button, action, mods)
        addbuttons(scene, :mousebuttons, button, action, Mouse.Button)
    end
    disconnect!(window, mouse_buttons)
    GLFW.SetMouseButtonCallback(window, mousebuttons)
end
function disconnect!(window::GLFW.Window, ::typeof(mouse_buttons))
    GLFW.SetMouseButtonCallback(window, nothing)
end
function keyboard_buttons(scene::Scene, window::GLFW.Window)
    event = scene.events.keyboardbuttons
    @csafe function keyoardbuttons(window, button, scancode::Cint, action, mods::Cint)
        addbuttons(scene, :keyboardbuttons, button, action, Keyboard.Button)
    end
    disconnect!(window, keyboard_buttons)
    GLFW.SetKeyCallback(window, keyoardbuttons)
end

function disconnect!(window::GLFW.Window, ::typeof(keyboard_buttons))
    GLFW.SetKeyCallback(window, nothing)
end

"""
Registers a callback for drag and drop of files.
returns `Node{Vector{String}}`, which are absolute file paths
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#gacc95e259ad21d4f666faa6280d4018fd)
"""
function dropped_files(scene::Scene, window::GLFW.Window)
    event = scene.events.dropped_files
    @csafe function droppedfiles(window, files)
        event[] = String.(files)
    end
    disconnect!(window, dropped_files)
    event[] = String[]
    GLFW.SetDropCallback(window, droppedfiles)
end
function disconnect!(window::GLFW.Window, ::typeof(dropped_files))
    GLFW.SetDropCallback(window, nothing)
end


"""
Registers a callback for keyboard unicode input.
returns an `Node{Vector{Char}}`,
containing the pressed char. Is empty, if no key is pressed.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function unicode_input(scene::Scene, window::GLFW.Window)
    event = scene.events.unicode_input
    @csafe function unicodeinput(window, c::Char)
        vals = event[]
        push!(vals, c)
        event[] = vals
        empty!(vals)
        event[] = vals
    end
    disconnect!(window, unicode_input)
    x = Char[]; sizehint!(x, 1)
    event[] = x
    GLFW.SetCharCallback(window, unicodeinput)
end
function disconnect!(window::GLFW.Window, ::typeof(unicode_input))
    GLFW.SetCharCallback(window, nothing)
end

# TODO memoise? Or to bug ridden for the small performance gain?
function retina_scaling_factor(w, fb)
    (w[1] == 0 || w[2] == 0) && return (1.0, 1.0)
    fb ./ w
end

function framebuffer_size(window::GLFW.Window)
    wh = GLFW.GetFramebufferSize(window)
    (wh.width, wh.height)
end
function window_size(window::GLFW.Window)
    wh = GLFW.GetWindowSize(window)
    (wh.width, wh.height)
end
function retina_scaling_factor(window::GLFW.Window)
    w, fb = window_size(window), framebuffer_size(window)
    retina_scaling_factor(w, fb)
end

function correct_mouse(window::GLFW.Window, w, h)
    ws, fb = window_size(window), framebuffer_size(window)
    s = retina_scaling_factor(ws, fb)
    (w * s[1], fb[2] - (h * s[2]))
end

"""
Registers a callback for the mouse cursor position.
returns an `Node{Vec{2, Float64}}`,
which is not in scene coordinates, with the upper left window corner being 0
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function mouse_position(scene::Scene, window::GLFW.Window)
    event = scene.events.mouseposition
    @csafe function cursorposition(window, w::Cdouble, h::Cdouble)
        event[] = correct_mouse(window, w, h)
    end
    disconnect!(window, mouse_position)
    GLFW.SetCursorPosCallback(window, cursorposition)
end
function disconnect!(window::GLFW.Window, ::typeof(mouse_position))
    GLFW.SetCursorPosCallback(window, nothing)
end

"""
Registers a callback for the mouse scroll.
returns an `Node{Vec{2, Float64}}`,
which is an x and y offset.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#gacc95e259ad21d4f666faa6280d4018fd)
"""
function scroll(scene::Scene, window::GLFW.Window)
    event = scene.events.scroll
    @csafe function scrollcb(window, w::Cdouble, h::Cdouble)
        event[] = (w, h)
        event[] = (0.0, 0.0)
    end
    disconnect!(window, scroll)
    GLFW.SetScrollCallback(window, scrollcb)
end
function disconnect!(window::GLFW.Window, ::typeof(scroll))
    GLFW.SetScrollCallback(window, nothing)
end

"""
Registers a callback for the focus of a window.
returns an `Node{Bool}`,
which is true whenever the window has focus.
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#ga6b5f973531ea91663ad707ba4f2ac104)
"""
function hasfocus(scene::Scene, window::GLFW.Window)
    event = scene.events.hasfocus
    @csafe function hasfocuscb(window, focus::Bool)
        event[] = focus
    end
    disconnect!(window, hasfocus)
    GLFW.SetWindowFocusCallback(window, hasfocuscb)
end
function disconnect!(window::GLFW.Window, ::typeof(hasfocus))
    GLFW.SetWindowFocusCallback(window, nothing)
end

"""
Registers a callback for if the mouse has entered the window.
returns an `Node{Bool}`,
which is true whenever the cursor enters the window.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga762d898d9b0241d7e3e3b767c6cf318f)
"""
function entered_window(scene::Scene, window::GLFW.Window)
    event = scene.events.entered_window
    @csafe function enteredwindowcb(window, entered::Bool)
        event[] = entered
    end
    disconnect!(window, entered_window)
    GLFW.SetCursorEnterCallback(window, enteredwindowcb)
end

function disconnect!(window::GLFW.Window, ::typeof(entered_window))
    GLFW.SetCursorEnterCallback(window, nothing)
end
