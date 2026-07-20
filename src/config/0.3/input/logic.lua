InputConfig({
	name = "Logic Pro (Z/X/A/S)",
	author = "RetroPlugMac"
})

-- Logic-friendly Game Boy controls. These are active only while the plugin
-- editor has keyboard focus and can be customized by copying/editing this map.
KeyMap({
	[Key.UpArrow] = Button.Up,
	[Key.LeftArrow] = Button.Left,
	[Key.DownArrow] = Button.Down,
	[Key.RightArrow] = Button.Right,

	[Key.A] = Button.Select,
	[Key.S] = Button.Start,

	[Key.Z] = Button.B,
	[Key.X] = Button.A,
})

GlobalKeyMap({
	[Key.Tab] = Action.RetroPlug.NextSystem,
	[{ Key.Ctrl, Key.S }] = Action.RetroPlug.SaveProject
})

-- Convenience actions for LSDj. Direct multi-button combinations such as
-- A+B and Select+D-pad also work by holding their mapped keys together.
KeyMap({ romName = "LSDj*" }, {
	[{ Key.Ctrl, Key.X }] = Action.Lsdj.Cut,
	[{ Key.Ctrl, Key.C }] = Action.Lsdj.Copy,
	[{ Key.Ctrl, Key.V }] = Action.Lsdj.Paste,
	[Key.Delete] = Action.Lsdj.Delete,
	[Key.PageDown] = Action.Lsdj.DownTenRows,
	[Key.PageUp] = Action.Lsdj.UpTenRows,
	[Key.Shift] = Action.Lsdj.BeginSelection,
	[Key.Esc] = Action.Lsdj.CancelSelection,
})
