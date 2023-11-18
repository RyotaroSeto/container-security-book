package user.dockerfile.ID001

__rego_metadata__ = {
	"id": "ID001",
	"title": "Registry is forbidden",
	"severity": "HIGH",
	"type": "Custom Dockerfile Check",
	"description": "Deny anything other than the allowed Docker registry.",
}

__rego_input__ = {"selector": [{"type": "dockerfile"}]}

allowed_redistries = ["hub.example.com"]

deny[msg] {
	op := input.stages[_][_]
	op.Cmd == "from"
	not startswith(op.Value[x], allowed_redistries[x])
	msg := sprintf("This image registry is not forbidden: %s", [op.Value[x]])
}
