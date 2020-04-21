package main

import (
	"fmt"
	"os"
	"os/exec"
	"path"
	"strings"

	hg "bitbucket.org/gohg/gohg"
	git "github.com/go-git/go-git/v5"
	"github.com/shirou/gopsutil/host"
	"github.com/shirou/gopsutil/load"
	"github.com/shirou/gopsutil/process"
)

func checkError(err error, msg string) {
	if err != nil {
		panic(fmt.Sprintf("%s: %s\n", msg, err))
	}
}

func printError(err error) error {
	if err != nil {
		fmt.Println(err)
	}

	return err
}

func gitStatus() string {
	var root string
	var added, modified, deleted, untracked int

	repo, err := git.PlainOpen(".")

	if err != nil {
		return ""
	}

	remotes, err := repo.Remotes()

	if printError(err) != nil {
		return ""
	}

	if len(remotes) > 0 {
		remote := remotes[0].Config()
		url := remote.URLs[0]
		root = path.Base(url)
	} else {
		dir, _ := os.Getwd()
		root = path.Base(dir)
	}

	root = strings.TrimSuffix(root, ".git")

	head, err := repo.Head()

	if printError(err) != nil {
		return ""
	}

	branch := string(head.Name())
	branch = strings.TrimLeft(branch, "refs/heads")
	revision := head.Hash().String()

	worktree, err := repo.Worktree()

	if err == nil {
		status, err := worktree.Status()
		if err == nil {
			for _, stat := range status {
				switch {
				case stat.Staging == git.Added || stat.Worktree == git.Added:
					added++
				case stat.Staging == git.Modified || stat.Worktree == git.Modified:
					modified++
				case stat.Staging == git.Deleted || stat.Worktree == git.Deleted:
					deleted++
				case stat.Worktree == git.Untracked:
					untracked++
				}
			}
		}
	}

	return fmt.Sprintf("git %s %s %s %dm %da %dd %du", root, branch, revision, modified, added, deleted, untracked)
}

func hgStatus() string {
	hgcl := hg.NewHgClient()

	err := hgcl.Connect("hg", ".", nil, false)

	if err != nil {
		return ""
	}

	defer hgcl.Disconnect()

	root := path.Base(hgcl.RepoRoot())

	id, err := hgcl.Identify([]hg.HgOption{}, []string{"--debug", "-i", "-b"})

	if printError(err) != nil {
		return ""
	}

	split := strings.Split(strings.TrimRight(string(id), "\n"), " ")
	revision := split[0]
	branch := split[1]

	status, err := hgcl.Status([]hg.HgOption{}, []string{})

	if printError(err) != nil {
		return ""
	}

	added := 0
	deleted := 0
	modified := 0
	untracked := 0
	var char string

	lines := strings.Split(string(status), "\n")

	for _, line := range lines {
		if line == "" {
			continue
		}
		switch char = string(line[0]); char {
		case "M":
			modified++
		case "A":
			added++
		case "D":
		case "R":
			deleted++
		default:
			untracked++
		}
	}

	return fmt.Sprintf("hg %s %s %s %dm %da %dd %du", root, branch, revision, modified, added, deleted, untracked)
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
	var vcs string

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

	var myos string
	var version string
	if info.OS == "darwin" {
		myos = "MacOS"
		version = info.PlatformVersion
	} else {
		myos = info.OS
		version = info.KernelVersion
	}

	myos = strings.Title(myos)
	vcs = gitStatus()

	if _, defined := os.LookupEnv("BASH_PROMPT_SKIP_VCS_CHECK"); !defined {
		vcs = gitStatus()

		if vcs == "" {
			vcs = hgStatus()
		}
	}

	fmt.Printf("load=\"%.2f %.2f %.2f\"\n", loadavg.Load1, loadavg.Load5, loadavg.Load15)
	fmt.Printf("myos=\"%s\"\n", myos)
	fmt.Printf("myversion=\"%s\"\n", version)
	fmt.Printf("tty=\"%s\"\n", terminal)
	fmt.Printf("users=\"%d\"\n", users)
	fmt.Printf("vcs=\"%s\"\n", vcs)
}
