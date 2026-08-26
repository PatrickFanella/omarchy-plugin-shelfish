const assert = require("node:assert/strict")
const Model = require("../Model.js")

const base = Model.normalizeConfig({
  groups: '[{"id":"work","name":"Work","icon":"W","direction":"left","widgets":["clock","clock"]},{"id":"other","name":"Other","widgets":["clock","mail"]}]',
  activeGroupId: "missing",
  watchedPaths: "clock=state|nested.value;mail=count",
  policies: '{"clock":{"autoReveal":false,"revealSeconds":12}}'
})

assert.equal(base.activeGroupId, "work")
assert.deepEqual(base.groups[0].widgets, ["clock"])
assert.deepEqual(base.groups[1].widgets, ["mail"])
assert.deepEqual(base.watchedPaths.clock, ["state", "nested.value"])
assert.deepEqual(base.policies.clock, { autoReveal: false, revealSeconds: 12 })
assert.equal(base.groups[0].icon, "W")
assert.equal(base.groups[0].direction, "left")

let config = Model.addGroup(base, "Work")
assert.equal(config.groups[2].id, "work-2")
config = Model.renameGroup(config, "work-2", "Personal")
assert.equal(Model.groupById(config, "work-2").name, "Personal")
config = Model.updateGroup(config, "work-2", { icon: "P", direction: "left" })
assert.equal(Model.groupById(config, "work-2").icon, "P")
assert.equal(Model.groupById(config, "work-2").direction, "left")
config = Model.moveGroup(config, "work-2", -1)
assert.equal(config.groups[1].id, "work-2")
config = Model.deleteGroup(config, "work")
assert.equal(config.activeGroupId, "work-2")

config = Model.setWidgetMembership(config, "work-2", "weather", true)
assert.equal(Model.widgetGroupId(config, "weather"), "work-2")
config = Model.setWidgetMembership(config, "work-2", "clock", true)
config = Model.setWidgetMembership(config, "work-2", "mail", true)
assert.deepEqual(Model.groupById(config, "other").widgets, [])
config = Model.moveWidget(config, "work-2", "mail", -1)
assert.deepEqual(Model.groupById(config, "work-2").widgets, ["weather", "mail", "clock"])

const item = { shelfishStatus: "busy", nested: { value: 3 } }
const snapshot = Model.statusSnapshot(item, "clock", { clock: ["nested.value"] })
assert.match(snapshot, /nested.value/)
assert.match(snapshot, /shelfishStatus/)
assert.equal(Model.valueAtPath(item, "nested.value"), 3)

const serialized = Model.serializeConfig(config)
assert.equal(Model.normalizeConfig(serialized).groups[0].name, "Personal")
assert.deepEqual(Object.keys(Model.normalizeConfig(serialized).groups[0]).sort(), ["direction", "icon", "id", "name", "widgets"])

const firstClock = { id: "clock", settings: { format: "short" } }
const secondClock = { id: "clock", settings: { format: "long" } }
const layout = {
  left: [firstClock, { id: "io.github.patrickfanella.shelfish.group.old" }],
  center: [secondClock],
  right: [{ id: "io.github.patrickfanella.shelfish" }, { id: "mail", color: "blue" }]
}
assert.equal(Model.syncGroupEntries(layout, [{
  id: "work", direction: "right", widgets: ["clock"]
}], "io.github.patrickfanella.shelfish", "io.github.patrickfanella.shelfish.group.", "/plugin"), true)
assert.deepEqual(layout.left, [])
assert.deepEqual(layout.center, [])
assert.equal(layout.right[1].id, "io.github.patrickfanella.shelfish.group.work")
assert.strictEqual(layout.right[2], firstClock)
assert.strictEqual(layout.right[3], secondClock)
assert.deepEqual(layout.right[2].settings, { format: "short" })
assert.deepEqual(layout.right[3].settings, { format: "long" })
assert.equal(Model.removeGeneratedEntries(layout, "io.github.patrickfanella.shelfish.group."), true)
assert.deepEqual(layout.right.map(entry => entry.id), ["io.github.patrickfanella.shelfish", "clock", "clock", "mail"])

const shortcutLayout = { left: [{ id: "shelfish" }], center: [], right: [] }
assert.equal(Model.syncGroupEntries(shortcutLayout, [{ id: "one", name: "One", icon: "*", direction: "right", widgets: ["shelfish.settings"] }], "shelfish", "shelfish.group.", "/tmp/shelfish"), true)
assert.equal(shortcutLayout.left[1].id, "shelfish.group.one")
assert.equal(shortcutLayout.left[2].id, "shelfish.group.one.settings")
assert.deepEqual(Model.allWidgetIds({ groups: [{ widgets: ["shelfish.settings", "clock"] }] }), ["clock"])

console.log("model tests passed")
