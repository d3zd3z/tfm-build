/* Bug workaround. */

/*
 * Compile this simple program to place in front of an executable
 * command to fix the signal blocking issue described in:
 * https://github.com/racket/racket/issues/2176, once this fix
 * propagates to a release, this will no longer be necessary.
 */

#include <signal.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char *const argv[], char *const envp[])
{
	sigset_t set;

	/* Unblock SIGCHLD */
	sigfillset(&set);
	sigprocmask(SIG_UNBLOCK, &set, NULL);

	signal(SIGFPE, SIG_DFL);
	signal(SIGPIPE, SIG_DFL);

	return execve(argv[1], argv+1, envp);
}
