package user.dockerfile.ID001

test_registry_allowed {
	r := deny with input as {"Stages": [{
		"Name": "ubuntu:22.04",
		"Command": [{"Cmd": "from", "Value": ["hub.example.com/ubuntu:20.04"]}],
	}]}
	count(r) == 0
}
