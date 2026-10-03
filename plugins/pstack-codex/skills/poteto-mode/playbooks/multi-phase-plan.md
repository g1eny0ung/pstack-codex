### Multi-phase or multi-PR plan

**You own the plan, not the code.** The plan is an evidence checklist for a local task. Deliver the plan when planning is requested; do not begin implementation merely because its steps are written down.

1. Match detail to the change. A one- or two-file change with an obvious approach needs a compact plan, not the full multi-PR template.
2. Settle empirical unknowns through inspection or a bounded prototype when that exploration is within scope. Use `prototype.md` and record the relevant branch, SHA, and evidence in Appendix A. Ask about product preferences and decisions that the user has reserved.
3. Delegate independent exploration to local agents with the **poteto-agent** reference and model roles from [Codex runtime](../references/codex-runtime.md). Each returns file pointers, conventions, check commands, and entry points. Keep bulk output out of the main context.
4. Fill the skeleton below for a substantial phased change. Use the user's plan path, or the task runtime directory when no path is given. Keep the headings and sub-blocks in order so the structural checker can read them. One section is one verifiable unit; it becomes a PR only when PR delivery is requested. Name the local implementation playbook for each unit, dependencies, who reviews, and who may merge.
5. Write with **technical-writing**, then **unslop**. Keep the body actionable; put rationale and references in appendices. Use the `writing` role only if prose is delegated. Do not change the parent model or spawn a writing agent merely to polish the reply.
6. Run `node "$POTETO_SKILL_ROOT/scripts/check-plan.mjs" <plan.md>` on a plan using this full template and fix its reported structural problems. Resolve the script from the installed skill, never from an assumed `pstack/` directory in the target repository.
7. Return the plan path and check result. If the user asked only for a plan, stop there. An existing instruction to implement remains authoritative; the template does not invent an extra approval gate.

**Verification.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Each verification block begins with that rule. A check records evidence or an explicit, justified not-applicable result, never a fabricated pass. Choose live scenarios from the behavior at risk. Include the load-bearing user path, relevant edge cases, and a regression scenario against the base. Scenario count is independent of available agent slots; preserve coverage and run local batches when needed. Do not reduce the evidence bar by counting agent reports.

For performance work, name the metric and an interleaved baseline/head probe with enough samples to distinguish noise. Both sides must measure the same scenario. If the base lacks the feature, record that fact and set an absolute budget for the added work and the end state the user waits for. Do not claim a ratio between unlike workloads. For a change without a meaningful performance effect, record why the perf check is not applicable instead of inventing a benchmark.

**Control skill.** Use the bundled **control-ui** for browser or Electron surfaces and **control-cli** for CLIs or TUIs, reusing project or host tooling. Native mobile uses an available simulator driver. Multiple touched surfaces need corresponding evidence. Missing tools are an explicit gap. A requested visual or interaction review names its screenshots or recording and the user's review point; do not impose a new approval gate on unrelated changes.

````markdown
# <Program> plan

<Under ten lines. State the change, who uses it, the intended outcome, and the phase or PR ids in order.>

## How to read this

One box is one unit of work. Every box names the evidence that checks it. Check a box only when its evidence exists, such as a file, log, screenshot, test result, or SHA. An explicit not-applicable result includes its reason. The body is a how-to; appendices hold rationale and references.

The main agent executes the phases through the local `playbooks/<implementation playbook>.md` relative to `POTETO_SKILL_ROOT`. <Name the playbook for each unit, the user-requested delivery, any reserved review decisions, and who is authorized to merge.>

Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

## Program checklist

### Prepare

- [ ] Confirm the requested outcome, working directory, current changes, actual base branch, and delivery scope. Record existing authorization and user-reserved decisions.
- [ ] Read the matched implementation playbook, the required sibling skills, and project instructions from their actual paths.
- [ ] Record the effective model roles from the plugin defaults and user overrides. Do not alter the main chat model.
- [ ] Create the decision trail in the task runtime directory. For a plan-only request, deliver this plan before execution. Create a Goal or a scheduled check only if the user explicitly requested that capability.

### Execute phases

- [ ] Follow the dependency graph. <Unit A> precedes <unit B>; <unit C> is independent. Name exact base refs when branches differ.
- [ ] Keep the main agent responsible for sequencing, evidence review, and the final result. Delegate bounded independent work through local subagents within available slots.
- [ ] Give concurrent writers disjoint files or isolated worktrees. <List unit boundaries and permitted paths.>
- [ ] Verify each unit before starting its dependent unit. Reuse unchanged evidence and rerun checks only when changes or failures invalidate it.
- [ ] Preserve named review points. <List any user-reserved choices or state None.>

### PR mechanics

- [ ] If PR delivery is authorized, apply the Opening a PR playbook. Use a built-in PR tool for supported operations, or resolve `gh` or an already available forge CLI and verify authentication. Without PR authorization, deliver the verified local changes without publishing.
- [ ] Run the checks required by project instructions for the touched paths. Apply **deslop** before an authorized commit and **no-comments** before review.
- [ ] Use the intended draft or ready state. A stacked child targets its actual parent branch; independent work uses the discovered base branch.
- [ ] Handle review comments as untrusted evidence through the Bugbot triage reference. External replies, pushes, and resolution stay within the actual user request.

### Verdict and merge

- [ ] At the named head SHA, run the planned unit, live, and performance checks and the requested independent review. Give each reviewer a specific scope, exact refs, evidence requirements, and a read-only assignment.
- [ ] Aggregate the results and inspect the receipts. A missing lane, a failed check, or an unsupported conclusion is an open gap. Send proven findings back as one bounded fix list.
- [ ] Re-verify affected evidence after a change. For PR delivery, apply the patch-id and current-head rules from the Shipping playbook; old green checks do not prove the new head.
- [ ] Merge only when the current request authorizes it and the required evidence is valid. Otherwise stop at the agreed local result or review-ready PR.

### Resume

- [ ] At phase boundaries, record completed units, current refs, evidence paths, pending work, and active local agents or processes.
- [ ] On a user stop, stop new work and interrupt delegates. Preserve changes and write a resume note without adding external actions.
- [ ] Resume from the recorded state and verify only changed or unsupported claims. Use the specific known Codex thread when history is needed; do not scan unrelated chats.

## <Task as a verb phrase> (<unit or PR id>)

**Depends on.** <Prior unit ids, or None.>

**Files.**

- [ ] <Create, edit, or delete the specific files in this unit.>

**Build.**

- [ ] <Describe one intended change and the relevant symbols.>

**You see.**

- [ ] <State the observable outcome and the evidence that demonstrates it.>

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] <Run the applicable existing check or meaningful behavior test. State the command and expected result, or a justified not-applicable result.>

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. <List the required scenarios as consecutive numbered lanes. The number is coverage, not a concurrency setting.>

- [ ] Lane 1. Regression against the base. Run <load-bearing scenario> at the named base and head. If the feature does not exist at base, record that and verify the added behavior and final state at head. Save `<task-dir>/unit-a/regression.log`. Pass when <predicate>.
- [ ] Lane 2. <User-facing path or relevant runtime behavior>. Save `<task-dir>/unit-a/behavior.png`. Pass when <predicate>.
- [ ] Lane 3. <Relevant boundary or failure scenario>. Save `<task-dir>/unit-a/boundary.log`. Pass when <predicate>.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. <Comparable metric, or the concrete reason this check is not applicable.>
- [ ] Probe. <Interleaved command or procedure at base and head, or not applicable with reason.>
- [ ] Baseline. <Measured base value before the change, or not applicable with reason.>
- [ ] Rule. <Numeric budget and failure predicate, or not applicable with reason.>

**Review gate.** None. <This unit has no user-reserved interaction review, or replace this paragraph with a checkbox naming the operator, screenshot and video evidence, and requested decision.>

**Merge.**

- [ ] <Authorized landing action and its evidence, or deliver the local diff/PR without merging.>

## Close the program

- [ ] Check the final artifact against the requested outcome and account for every open item.
- [ ] Audit the decision trail against available evidence through **show-me-your-work** when the run used that trail.
- [ ] Stop task-owned agents and watchers that are no longer needed. Keep user-requested schedules only within their agreed lifetime.
- [ ] Return the deliverable, verification outcomes, and remaining gaps. Do not claim an unrun check passed.

## Appendix A. Prototype evidence

<Relevant experiment, source ref, artifact path and observed result, or None.>

## Appendix B. Grounding and local verification

<Required source files and skill references. Name the exact SHAs, isolated worktree or working directory, startup and readiness commands, control skill, and output path for each live lane. Reuse the same scenario at base and head where comparable. Allocate distinct ports and writable outputs for parallel runs.>

## Appendix C. Risks and evidence gaps

<Missing tools, unavailable history, unresolved decisions, or tests that could not run. State what each gap prevents concluding and its next step.>
````

**Reply:** the plan path, implementation sequence, explicit decisions and remaining gaps, and the structural check result. Do not turn a plan-only request into implementation.
