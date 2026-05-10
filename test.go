package main

import (
	"encoding/json"
	"fmt"
	"os"
)

func main() {
	pluginFrom := os.Getenv("PLUGIN_FROM")
	fmt.Printf("PLUGIN_FROM: %s\n", pluginFrom)
}