//go:build windows

package agents

import (
	"errors"
	"os/exec"
	"syscall"
)

func detach(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: syscall.CREATE_NEW_PROCESS_GROUP}
}

func exitCode(err error) int {
	var ee *exec.ExitError
	if !errors.As(err, &ee) || ee.ExitCode() < 0 {
		return 1
	}
	return ee.ExitCode()
}
