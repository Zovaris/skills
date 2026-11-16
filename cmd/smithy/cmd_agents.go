package main

import "github.com/Zovaris/skills/internal/agents"

func init() {
	register("agent", "run one headless agent CLI on a prompt file", agents.AgentMain)
	register("consult", "ask the strongest model to settle one decision", agents.ConsultMain)
	register("route", "pick the model tier for a task", agents.RouteMain)
	register("skills", "find installed skills (smithy skills --list)", agents.SkillsMain)
	register("setup", "use-smithy setup: installed skills, settings, instructions block", agents.SetupMain)
}
