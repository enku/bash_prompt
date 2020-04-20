package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/shirou/gopsutil/host"
	"github.com/shirou/gopsutil/load"
	"github.com/shirou/gopsutil/process"
)

func checkError(err error, msg string) {
	if err != nil {
		panic(fmt.Sprintf("%s: %s\n", msg, err))
	}
}

func getTty() string {
	cmd := exec.Command("tty")
	cmd.Stdin = os.Stdin
	out, err := cmd.CombinedOutput()

	if err != nil {
		return "?"
	}

	return strings.TrimSpace(strings.TrimPrefix(string(out), "/dev/"))
}

func main() {
	info, err := host.Info()
	checkError(err, "Could not obtain platform information")

	loadavg, err := load.Avg()
	checkError(err, "Could not get load average")

	userStats, err := host.Users()
	checkError(err, "Could not enumerate users")
	users := len(userStats)

	myPid := int32(os.Getpid())
	myProcess, err := process.NewProcess(myPid)
	checkError(err, "Failed to get process")
	pprocess, err := myProcess.Parent()
	checkError(err, "Failed to get parent process")
	terminal, err := pprocess.Terminal()

	if err != nil {
		terminal = getTty()
	}
	terminal = strings.TrimPrefix(terminal, "/")

	var os string
	var version string
	if info.OS == "darwin" {
		os = "MacOS"
		version = info.PlatformVersion
	} else {
		os = info.OS
		version = info.KernelVersion
	}

	os = strings.Title(os)

	fmt.Printf("load=\"%.2f %.2f %.2f\"\n", loadavg.Load1, loadavg.Load5, loadavg.Load15)
	fmt.Printf("myos=\"%s\"\n", os)
	fmt.Printf("myversion=\"%s\"\n", version)
	fmt.Printf("tty=\"%s\"\n", terminal)
	fmt.Printf("users=\"%d\"\n", users)
}
