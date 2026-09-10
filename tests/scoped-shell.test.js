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
  const ctx = {shell: {barConfig}}
  assert.equal(qmlFunction("Service.qml", "currentConfig", ctx)().bar, barConfig)
})
test("unsupported grouping never reports success or invokes mutation", () => {
  let calls = 0
  const ctx = {suspended: false, groupingAvailable: false, shell: {mutateShellConfig: () => {calls++}}}
  assert.equal(qmlFunction("Service.qml", "persist", ctx)({}), false)
  qmlFunction("Service.qml", "ensureGroupEntries", ctx)()
  qmlFunction("Service.qml", "reconcileSlots", ctx)()
  assert.equal(calls, 0)
})
