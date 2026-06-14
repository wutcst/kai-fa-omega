# Copilot instructions for first_demo (Godot C#)

Purpose
- Make AI coding agents productive quickly by surfacing project-specific patterns, build/debug workflows, and notable files.

Big picture
- This is a Godot 4 project using Godot.NET.Sdk for C# scripts. The C# assembly is compiled separately and loaded by Godot (see `first_demo.csproj`).
- Runtime: Godot engine uses the generated .NET assembly (EnableDynamicLoading=true) so edits require rebuilding the C# project before running in the editor.

Key files
- project.godot: engine settings (renderer, physics, icon). Example: rendering driver set to `d3d12` on Windows.
- first_demo.csproj: uses `Godot.NET.Sdk/4.6.2`, `TargetFramework` = `net8.0` (android uses net9.0). Important property: `EnableDynamicLoading`.
- `NewScript.cs`: example script. Note: scripts are ordinary C# partial classes that inherit Godot node types and are referenced from scene files.

Build / Run (concrete commands)
- Restore and build the C# assembly:

  dotnet restore
  dotnet build -c Debug

- Built assembly path (example): `bin/Debug/net8.0/first_demo.dll` — Godot loads this at runtime. After build, open the project in Godot Editor or run the Godot executable to test scenes.
- Prefer running in the Godot editor for scene-driven iteration; building only compiles the managed assembly.

Debugging
- Typical workflow: launch Godot Editor (or exported project) and attach a .NET debugger (Visual Studio / VS Code) to the running process. Set breakpoints in the C# sources.
- For VS Code: use the .NET Core attach configuration and attach to the Godot process (look for `Godot` executable). Ensure symbols are from the matching build configuration.

Project-specific conventions
- Scripts are named to match class names and are simple `partial` classes inheriting Godot node types (see `NewScript.cs`).
- Keep `EnableDynamicLoading` = true so Godot can reload the managed assembly without manual export steps.
- Cross-platform note: `first_demo.csproj` targets `net8.0` for desktop and `net9.0` for Android (conditional). Respect those when adding package references.

Common pitfalls & examples
- Broken script example: `NewScript.cs` currently contains an incomplete `GD` call — fix by using `GD.Print()` or removing the stray token. AI edits should preserve Godot method signatures (`_Ready()`, `_Process(double delta)`).
- If Godot fails to load scripts after a build, confirm the assembly path (`bin/Debug/...`) and restart the Godot editor to force reloading.

Integration points
- No external network services detected in the repo. The main integration is between Godot engine and the compiled .NET assembly.

When editing
- Preserve the node lifecycle methods and visibility (public overrides). Avoid changing public API names used by scenes.

If you need more
- Tell me about CI, export profiles, or which editor you use (VS Code vs Visual Studio) and I will add attach/debug configs and CI build steps.

---
Generated from repository files: `project.godot`, `first_demo.csproj`, `NewScript.cs`.
