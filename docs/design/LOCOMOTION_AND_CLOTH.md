# Locomotion and cloth: the plan

Status: **Phase A built** (2026-10-12). The rest is planned, with measurable acceptance for each step.

## Target (honest)
Rockstar's RDR2 feel is built on a motion-matching style database of thousands of mocap clips plus proprietary systems. We cannot match the *breadth*. We can match what a player actually reads in the first minute: **weight** (things take time to start and stop), **intent** (the body leans and turns before the legs commit), **contact** (feet planted, no skating), **continuity** (no pops between states), and **secondary motion that never visibly breaks** (cloth and hair never go through the body or the gear).

## What we have
- UAL idle / walk / jog (CC0), a speed-matched blend space with stride scaling, pelvic tilt and head stabilisation (`GaitPolish`), terrain foot grounding (`FootGrounder`), bank and lean, native `SpringBoneSimulator3D` for hair, skirt and capelet with body capsules (`CharacterPhysics`).
- No start, stop, turn-in-place or strafe clips (UAL Standard has none).

## Phases

| Phase | Work | Acceptance (measured) |
|---|---|---|
| **A. Weight** (done) | Jerk-limited acceleration, speed-dependent turn rate (a run takes an arc, a hard turn costs speed), stand-start turns to face first, heading-following body, stronger lean from acceleration, camera FOV by speed, NPC ease in and out | Smoke test: 90% of walk speed in 0.35-1.1 s (now 0.63 s), step from walk to run 0.4-1.7 s (0.58 s), stop from a run 0.4-1.4 s (0.85 s), a 180 degree turn at a run dips speed below 80% and not below 0.2 m/s (2.5 of 3.4 m/s) |
| **B. Clips** | Curate CMU mocap (free for any use; pipeline exists in `art/blender/mocap_retarget.py`): walk start, walk stop, run start, run stop, 90/180 turns, strafe. Retarget to the humanoid library. A small gait state machine: Idle, Start, Walk, Jog, Stop, Pivot, Air, Land. Foot-phase aware blending (no mid-stride pops) | Each transition appears once in a scripted run; no state change moves the pelvis more than 6 cm in one frame; a foot-contact slide metric under 5 cm per step (needs a reliable contact detector: the quick ankle-height probe in the smoke test was removed because it was not) |
| **C. Contact** | Better slope handling (pelvis tilt, leg-length adaptation), stairs, step-up on small rises, head and eye lead into turns, hand IK to the staff held while walking | Walk the test slope and the step ramp with no foot below the terrain, none floating more than 4 cm |
| **D. Cloth and hair clipping** | An objective clip metric: sample every hair and cloth bone against the body and the garment colliders over a scripted motion suite (walk, run, turns, jump, cast, sit, flight, lying-down pose) and count penetrations and their depth. Then fix by coverage: more collider volumes where the metric finds hits (shoulder, collar, upper arm, hip, thigh, capelet front/back), correct radii, per-chain stiffness, collision groups so hair collides with garment volumes and not only with the body | Zero penetrations deeper than 1 cm across the suite for the demo outfit; the metric runs in CI |
| **E. Gear system rule** | Data-driven colliders per garment (`outfit_colliders`), so equipping anything brings its volumes for hair and cloth. The Dragon's Dogma 2 failure mode (hair through armour) is exactly a missing garment volume | Adding a garment without colliders fails a test |

## Principles
- Everything measurable gets a number in a scripted run, because feel cannot be verified headless but regressions can.
- Tunables are exported constants (`accel_walk`, `accel_run`, `brake`, `jerk_time`, `turn_rate_*`), so they can be tuned by hand against the number.
- No framework import. Read AMSG and others for ideas only.

## Not planned for the demo
Full motion matching, ragdolls, climbing, horses and animals (a different locomotion rig), real mesh cloth (Godot has none; spring chains with colliders are the practical equivalent).
