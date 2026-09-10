const assert = require("node:assert/strict")
const test = require("node:test")
const fs = require("node:fs")
const vm = require("node:vm")
const path = require("node:path")
function qmlFunction(file, name, context) {
  const source = fs.readFileSync(path.join(__dirname, "..", file), "utf8")
  const match = source.match(new RegExp("^  function " + name + "\\([^]*?^  }", "m"))
  assert.ok(match, name)
  vm.runInNewContext(match[0] + "; this.call = " + name, context)
  return context.call
}

test("scoped host reads existing groups without private shell state", () => {
  const barConfig = {layout: {right: [{id: "io.github.patrickfanella.shelfish", groups: "[]"}]}}
  const ctx = {shell: {barConfig}, getHostBar: () => null}
  assert.equal(qmlFunction("Service.qml", "getEffectiveConfig", ctx)().bar, barConfig)
})
test("unsupported grouping never reports success or invokes mutation", () => {
  let calls = 0
  const ctx = {suspended: false, groupingAvailable: false, getEffectiveConfig: () => ({}), effectiveShell: {mutateShellConfig: () => {calls++}}}
  assert.equal(qmlFunction("Service.qml", "persist", ctx)({}), false)
  qmlFunction("Service.qml", "ensureGroupEntries", ctx)()
  qmlFunction("Service.qml", "reconcileSlots", ctx)()
  assert.equal(calls, 0)
})

test("merged host slot discovery enables grouping without raw shell state", () => {
  const ctx = {effectiveShell: {mutateShellConfig() {}}, getEffectiveConfig: () => ({bar: {}}), slots: () => [{moduleName: "widget"}]}
  const canGroup = qmlFunction("Service.qml", "canGroup", ctx)
  assert.equal(canGroup(), true)
  ctx.slots = () => []
  assert.equal(canGroup(), false)
  ctx.slots = () => [{moduleName: "widget"}]
  ctx.getEffectiveConfig = () => null
  assert.equal(canGroup(), false)
})

test("merged reconciliation collapses both slot and widget dimensions", () => {
  const slot = {moduleName: "managed.widget", visible: true, activeItem: {visible: true}}
  const ctx = {suspended: false, groupingAvailable: true, config: {}, managedIds: [],
    revealedGroupId: "", revision: 0, moduleName: "io.github.patrickfanella.shelfish",
    groupPrefix: "io.github.patrickfanella.shelfish.group.", slots: () => [slot],
    Model: {allWidgetIds: () => [slot.moduleName], groupById: (_, id) => id ? {widgets: [slot.moduleName]} : null}}
  ctx.root = ctx
  const reconcile = qmlFunction("Service.qml", "reconcileSlots", ctx)
  reconcile()
  assert.equal(slot.visible, false)
  assert.equal(slot.activeItem.visible, false)
  ctx.revealedGroupId = "default"
  reconcile()
  assert.equal(slot.visible, true)
  assert.equal(slot.activeItem.visible, true)
})
