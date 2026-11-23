local T = require("./harness")
T.test("eq compares nested tables by value", function()
	T.eq({ a = { 1, 2 }, b = "x" }, { a = { 1, 2 }, b = "x" })
end)
T.test("truthy and falsy", function()
	T.truthy(1)
	T.falsy(nil)
end)

T.test("eq and describe survive tables that contain themselves", function()
	local a: any = { n = 1 }
	a.self = a
	local b: any = { n = 1 }
	b.self = b
	T.eq(a, b)
	local c: any = { n = 2 }
	c.self = c
	local ok, err = pcall(T.eq, a, c)
	T.falsy(ok)
	T.truthy(string.find(tostring(err), "<cycle>", 1, true) ~= nil, tostring(err))
end)
