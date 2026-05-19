---
paths:
  - "**/*.js"
  - "**/*.ts"  
---

# TypeScript and JavaScript style guide

- 2-space indentation; single quotes (enforced by linter)
- Anchor to the Google TypeScript Style Guide, overriding where personal preferences conflict
- Enforcement: TBD to validate
- **Types**: prefer explicit types at public interfaces, exported functions, and complex return values. Avoid unnecessary local type annotations when inference is obvious.
- **Flags**: prefer discriminated unions over boolean configuration flags or loosely structured option objects.
- **Nullability**: Use undefined consistently for absent values unless null has semantic meaning. Avoid APIs that ambiguously mix null, undefined, and optional properties.
- **Async / promises**: Prefer explicit async/await flow over nested promise chains. Avoid floating promises.
- **Minimize mutation scope**: Prefer const by default. Keep mutable state narrowly scoped. Avoid shared mutable module state unless clearly justified.
