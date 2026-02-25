# Phase 3: CI/CD Integration - Research

**Researched:** 2026-02-24
**Domain:** GitHub Actions workflows, Docker Buildx caching, multi-tier image build chains
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CICD-01 | Variant added to build.yml GitHub Actions matrix | Matrix entry pattern documented; three-tier build chain solution provided |
| CICD-02 | Variant added to check.yml GitHub Actions matrix | Identical matrix entry pattern; check.yml differences (no push, no cache-to) documented |
| CICD-03 | GHA cache scope configured for the variant | Scope `flutter` confirmed unique; no collision with existing scopes (base, bun, php, rust, vnc) |
</phase_requirements>

## Summary

This phase adds the `trixie-vnc-flutter-rust-nvm-uv-claude` variant to both GitHub Actions workflows (`build.yml` and `check.yml`). The primary technical challenge is that this variant has a **three-tier build dependency chain** -- it extends the VNC variant (`FROM trixie-vnc-nvm-uv-claude:latest`), which itself extends the base image (`FROM devcontainer-base:latest`). All other existing variants have a simpler two-tier chain (base -> variant).

The current workflow pattern rebuilds the base image from GHA cache and pushes it to a local `registry:2` service container, then uses `build-contexts` to remap `devcontainer-base:latest` to the local registry. For the flutter variant, the same job must additionally build the VNC intermediate image from its GHA cache and push it to the local registry, then use `build-contexts` to remap `trixie-vnc-nvm-uv-claude:latest` to the local registry image.

The GHA cache scope `flutter` is unique and does not collide with existing scopes (`base`, `bun`, `php`, `rust`, `vnc`). The default 10 GB per-repository GHA cache limit and disk space on ubuntu-latest runners (14 GB guaranteed free) are potential constraints given the flutter image's size (~7-10 GB with Android SDK, Studio, emulator, and system images). The `timeout-minutes: 30` on existing jobs may be tight for the flutter variant due to the three-tier chain, but GHA cache should minimize rebuild time.

**Primary recommendation:** Add the flutter variant to both workflow matrices with an extra build step that rebuilds the VNC intermediate from cache and pushes to local registry, then remap `trixie-vnc-nvm-uv-claude:latest` via `build-contexts`.

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| docker/build-push-action | v6 | Build and push Docker images with Buildx | Already used by all existing variant builds |
| docker/setup-buildx-action | v3 | Set up Docker Buildx builder | Already used; required for GHA cache and build-contexts |
| docker/metadata-action | v5 | Extract Docker image metadata/tags | Already used for GHCR tagging |
| docker/login-action | v3 | Authenticate to GHCR | Already used for registry auth |
| registry:2 | latest | Local Docker registry service container | Already used for inter-step image passing |
| GHA cache (type=gha) | N/A | Layer caching for Docker builds | Already used; scope-based isolation prevents collisions |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| actions/checkout | v4 | Repository checkout | Every job (already present) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Local registry + build-contexts | Sequential job dependency (vnc job -> flutter job) | Would require a separate `vnc` build job just for flutter, adding workflow complexity and increasing total CI time; local registry approach keeps the pattern consistent with existing variants |
| Three-tier in same job | Bake file with target dependencies | Overkill for one chained variant; would require restructuring the entire workflow; current approach is minimal change |

## Architecture Patterns

### Current Two-Tier Workflow Pattern (Existing Variants)
```
base job:
  build base -> push to GHCR (build.yml) / build-only (check.yml)

variants job (matrix, parallel):
  rebuild base from GHA cache -> push to localhost:5000
  build variant with build-contexts remap -> push to GHCR (build.yml) / build-only (check.yml)
```

### Required Three-Tier Pattern (Flutter Variant)
```
base job:
  (unchanged)

variants job (matrix, parallel):
  [all variants] rebuild base from GHA cache -> push to localhost:5000
  [flutter ONLY] rebuild VNC from GHA cache -> push to localhost:5000
  [all variants] build variant with build-contexts remap -> push to GHCR / build-only
```

### Pattern: Extra Build Step for Chained Dependencies
**What:** The flutter variant's matrix entry includes an additional step that rebuilds the VNC intermediate image from its GHA cache and pushes it to the local registry, before the main variant build step.
**When to use:** When a variant's Dockerfile uses `FROM` on another variant (not the base image).
**Key insight:** Each matrix job runs in an isolated runner. The VNC image is NOT available from another matrix job. It must be rebuilt within the same job.

### Pattern: Conditional Steps via Matrix Variables
**What:** Use `if: matrix.needs_vnc == true` (or similar) to conditionally run the VNC rebuild step only for the flutter variant, keeping other variants unaffected.
**When to use:** When only some matrix entries need extra build steps.
**Alternative:** Use a separate matrix entry block for flutter without conditions. Since all steps execute sequentially within a job, an extra step that only applies to flutter can simply be present in the workflow and skipped via `if`.

### Anti-Patterns to Avoid
- **Sharing images between parallel matrix jobs:** Matrix jobs run on separate runners. You cannot push an image in the VNC job and expect the flutter job to access it. Each job has its own isolated `localhost:5000` registry.
- **Modifying the Dockerfile FROM line for CI:** The `build-contexts` remap exists precisely to avoid changing Dockerfiles. Never change `FROM trixie-vnc-nvm-uv-claude:latest` to something else for CI.
- **Using `cache-to` in check.yml:** The check workflow intentionally only reads cache. Adding `cache-to` would cause cache scope pollution and potentially evict useful cache from the build workflow.
- **Using the same scope for VNC and flutter:** Each must have its own cache scope. The VNC variant already has scope `vnc`. The flutter variant gets scope `flutter`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image tag generation | Custom shell scripts for tags | `docker/metadata-action@v5` | Handles semver, latest, branch patterns consistently |
| Cache key management | Manual cache key strings | `type=gha,scope=flutter` | GHA cache integration is built into buildx; scope isolation is automatic |
| Registry authentication | Manual `docker login` commands | `docker/login-action@v3` | Handles token management, supports multiple registries |
| Build-contexts remapping | Modified Dockerfiles for CI | `build-contexts` input on build-push-action | Keeps Dockerfiles identical between local and CI builds |

**Key insight:** The existing workflow already solves every CI/CD problem this phase encounters. The task is purely additive -- add matrix entries and one extra step. No new patterns or tools are needed.

## Common Pitfalls

### Pitfall 1: Forgetting VNC Cache Read for Flutter Build
**What goes wrong:** The flutter job rebuilds the VNC image from scratch because it only has `cache-from: type=gha,scope=base` for the VNC rebuild step, missing `cache-from: type=gha,scope=vnc`.
**Why it happens:** The VNC image's cache scope is `vnc`, not `base`. Forgetting to read from the correct scope causes a full uncached rebuild.
**How to avoid:** The VNC rebuild step MUST include `cache-from: type=gha,scope=vnc`.
**Warning signs:** Flutter variant CI build takes 20+ minutes instead of ~5-10.

### Pitfall 2: GHA Cache Eviction Due to Total Size
**What goes wrong:** Adding the flutter cache scope pushes total cache beyond 10 GB, causing LRU eviction of other scopes.
**Why it happens:** Default GHA cache limit is 10 GB per repository. The flutter image layers (Android SDK, Studio, emulator system images) are large (5-8 GB compressed cache).
**How to avoid:** Monitor cache usage after first build. If eviction occurs, consider enabling pay-as-you-go cache (requires Pro/Team/Enterprise plan) or accepting that some variants will have cold builds occasionally.
**Warning signs:** Previously fast builds suddenly take much longer; `cache-from` steps report no cache hit.

### Pitfall 3: Disk Space on ubuntu-latest Runner
**What goes wrong:** The build fails with "no space left on device" because the runner's 14 GB free space is consumed by base + VNC + flutter layers plus build cache.
**Why it happens:** ubuntu-latest guarantees only ~14 GB free space. Building three images sequentially (base, VNC, flutter) in one job accumulates layers.
**How to avoid:** BuildKit and the local registry do not store images as Docker daemon images (they stay in buildx cache), so actual disk usage is lower than naive image sizes suggest. Monitor in first CI run. If space is tight, add a `jlumbroso/free-disk-space@v1.3.1` step at the start.
**Warning signs:** Build fails with ENOSPC or "no space left on device".

### Pitfall 4: Timeout Exceeded for Flutter Variant
**What goes wrong:** The flutter variant build exceeds the 30-minute `timeout-minutes` because it must build base + VNC + flutter sequentially.
**Why it happens:** Three-tier chain with large downloads (Android SDK, Studio, Flutter) even from cache takes time.
**How to avoid:** GHA cache should make base and VNC rebuilds fast (~1-2 min each from cache). The flutter-specific layers are the bottleneck. If 30 minutes is too tight, increase `timeout-minutes` for the flutter variant specifically (or for the entire variants job).
**Warning signs:** Job cancelled with "The job running on runner ... has exceeded the maximum execution time."

### Pitfall 5: build-contexts Key Must Match FROM Line Exactly
**What goes wrong:** Build fails with "failed to solve: trixie-vnc-nvm-uv-claude:latest: not found" because the build-contexts key doesn't match the Dockerfile's FROM reference.
**Why it happens:** The `build-contexts` key must exactly match the image reference in `FROM`. If the Dockerfile says `FROM trixie-vnc-nvm-uv-claude:latest`, the key must be `trixie-vnc-nvm-uv-claude:latest`, not `trixie-vnc-nvm-uv-claude` (without tag).
**How to avoid:** Copy the exact string from the Dockerfile's FROM line as the build-contexts key.
**Warning signs:** "not found" error during build resolution.

## Code Examples

Verified patterns from existing workflow files and Docker official documentation.

### Matrix Entry for build.yml
```yaml
# Source: existing build.yml pattern + Docker named contexts docs
# Added to strategy.matrix.include array
- name: trixie-vnc-flutter-rust-nvm-uv-claude
  scope: flutter
  needs_vnc: true
```

### VNC Intermediate Rebuild Step (build.yml)
```yaml
# Source: existing "Rebuild base from cache" step pattern
# Inserted BEFORE the main variant build step
- name: Rebuild VNC from cache and push to local registry
  if: matrix.needs_vnc
  uses: docker/build-push-action@v6
  with:
    context: .
    file: trixie-vnc-nvm-uv-claude/Dockerfile
    push: true
    tags: localhost:5000/trixie-vnc-nvm-uv-claude:latest
    build-contexts: devcontainer-base:latest=docker-image://localhost:5000/devcontainer-base:latest
    cache-from: type=gha,scope=vnc
```

### Flutter Variant Build Step with Chained build-contexts (build.yml)
```yaml
# Source: existing variant build step + Docker multiple named contexts docs
# The build-contexts must remap the flutter variant's FROM reference
- name: Build and push ${{ matrix.name }}
  uses: docker/build-push-action@v6
  with:
    context: .
    file: ${{ matrix.name }}/Dockerfile
    push: true
    tags: ${{ steps.meta.outputs.tags }}
    labels: ${{ steps.meta.outputs.labels }}
    build-contexts: |
      ${{ matrix.needs_vnc && 'trixie-vnc-nvm-uv-claude:latest=docker-image://localhost:5000/trixie-vnc-nvm-uv-claude:latest' || 'devcontainer-base:latest=docker-image://localhost:5000/devcontainer-base:latest' }}
    cache-from: type=gha,scope=${{ matrix.scope }}
    cache-to: type=gha,mode=max,scope=${{ matrix.scope }}
```

**Note:** The build-contexts expression above uses a ternary to switch the remap target. For the flutter variant, the FROM line references `trixie-vnc-nvm-uv-claude:latest` (not `devcontainer-base:latest`), so the remap must match. For all other variants, the existing `devcontainer-base:latest` remap is used. An alternative is to use a matrix variable for the full build-contexts string.

### Alternative: Matrix Variable for build-contexts
```yaml
# Cleaner approach: store the full build-contexts value in the matrix
matrix:
  include:
    - name: trixie-bun-nvm-uv-claude
      scope: bun
      build_contexts: devcontainer-base:latest=docker-image://localhost:5000/devcontainer-base:latest
    - name: trixie-vnc-flutter-rust-nvm-uv-claude
      scope: flutter
      needs_vnc: true
      build_contexts: trixie-vnc-nvm-uv-claude:latest=docker-image://localhost:5000/trixie-vnc-nvm-uv-claude:latest
```

Then in the build step:
```yaml
build-contexts: ${{ matrix.build_contexts }}
```

### check.yml Differences
```yaml
# check.yml: NO cache-to, NO push for main variant build
# VNC intermediate step: push to local registry (needed), NO cache-to
- name: Rebuild VNC from cache and push to local registry
  if: matrix.needs_vnc
  uses: docker/build-push-action@v6
  with:
    context: .
    file: trixie-vnc-nvm-uv-claude/Dockerfile
    push: true  # push to LOCAL registry (not GHCR) -- required for flutter to consume
    tags: localhost:5000/trixie-vnc-nvm-uv-claude:latest
    build-contexts: devcontainer-base:latest=docker-image://localhost:5000/devcontainer-base:latest
    cache-from: type=gha,scope=vnc
    # NO cache-to -- check.yml never writes cache

# Main build step:
- name: Build ${{ matrix.name }}
  uses: docker/build-push-action@v6
  with:
    context: .
    file: ${{ matrix.name }}/Dockerfile
    push: false  # check.yml never pushes to GHCR
    build-contexts: ${{ matrix.build_contexts }}
    cache-from: type=gha,scope=${{ matrix.scope }}
    # NO cache-to -- check.yml never writes cache
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `docker/build-push-action@v5` | `docker/build-push-action@v6` | 2024 | v6 already in use; no migration needed |
| `registry:2` service container | `registry:3` now documented | 2025 | registry:2 still works; registry:3 is the latest but either is fine |
| 10 GB hard cache limit | Pay-as-you-go cache expansion | Nov 2025 | Can now exceed 10 GB if needed (requires paid plan) |
| No rate limits on cache | 200 uploads/min rate limit | Jan 2026 | Unlikely to affect this project (few uploads per run) |

**Deprecated/outdated:**
- `registry:2` vs `registry:3`: The docs now show `registry:3` but `registry:2` remains functional. Keeping `registry:2` for consistency with existing workflow is fine. Upgrading is optional.

## Open Questions

1. **Will the flutter cache fit within the 10 GB repository cache limit?**
   - What we know: Current scopes (base, bun, php, rust, vnc) already consume some cache. The flutter image has large layers (Android SDK ~3 GB, Android Studio ~1 GB, system images ~1.5 GB, Flutter SDK ~1 GB).
   - What's unclear: Actual compressed GHA cache size for each scope. BuildKit deduplicates layers within a scope but not across scopes.
   - Recommendation: Monitor after first successful build.yml run. If cache eviction occurs, evaluate pay-as-you-go or optimize layer ordering to maximize cache hits.

2. **Will the 30-minute timeout be sufficient?**
   - What we know: Existing variants build within 30 minutes. The flutter variant has a three-tier chain plus large downloads. With warm GHA cache, base and VNC rebuilds should be ~1-2 min each.
   - What's unclear: Cold build time for the flutter variant specifically (first ever run has no cache).
   - Recommendation: Start with 30 minutes. If the first run times out, increase to 45 or 60 minutes for the variants job. Could also increase only if matrix.needs_vnc is true, but that requires restructuring.

3. **Runner disk space adequacy?**
   - What we know: ubuntu-latest has ~14 GB free. BuildKit stores layers in its own cache, not as Docker daemon images. Three sequential builds (base, VNC, flutter) accumulate build cache.
   - What's unclear: Whether BuildKit garbage collects intermediate layers during the build chain.
   - Recommendation: Monitor first run. If disk space issues occur, add `jlumbroso/free-disk-space` action step.

## Sources

### Primary (HIGH confidence)
- `.github/workflows/build.yml` - Existing build workflow with two-tier pattern, all 4 variant matrix entries, registry service container, build-contexts usage
- `.github/workflows/check.yml` - Existing check workflow, confirms no cache-to, no push pattern
- `trixie-vnc-flutter-rust-nvm-uv-claude/Dockerfile` - Confirms `FROM trixie-vnc-nvm-uv-claude:latest` (three-tier dependency chain)
- `trixie-vnc-nvm-uv-claude/Dockerfile` - Confirms `FROM devcontainer-base:latest` (VNC is the intermediate tier)
- [Docker official docs: Named contexts with GitHub Actions](https://docs.docker.com/build/ci/github-actions/named-contexts/) - build-contexts syntax and multiple named contexts
- [Docker official docs: Local registry with GitHub Actions](https://docs.docker.com/build/ci/github-actions/local-registry/) - registry service container pattern

### Secondary (MEDIUM confidence)
- [GitHub blog: GHA cache size can now exceed 10 GB](https://github.blog/changelog/2025-11-20-github-actions-cache-size-can-now-exceed-10-gb-per-repository/) - Cache limit details, pay-as-you-go model
- [GitHub blog: Rate limiting for cache entries](https://github.blog/changelog/2026-01-16-rate-limiting-for-actions-cache-entries/) - 200 uploads/min rate limit (Jan 2026)
- [docker/build-push-action GitHub repo](https://github.com/docker/build-push-action) - build-contexts input is List type, supports multiple entries

### Tertiary (LOW confidence)
- [GitHub Actions runner images discussion #9329](https://github.com/actions/runner-images/discussions/9329) - ubuntu-latest disk space (~14 GB free); exact values may vary with runner image updates

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools already in use in existing workflows; no new tools needed
- Architecture: HIGH - Pattern is a direct extension of the existing two-tier pattern with one additional step
- Pitfalls: HIGH - Pitfalls derived from direct analysis of existing workflows and verified Docker documentation
- Cache/disk concerns: MEDIUM - Actual sizes unknown until first CI run; based on estimates from Dockerfile contents

**Research date:** 2026-02-24
**Valid until:** 2026-03-24 (stable -- GHA workflows and Docker buildx are mature)
