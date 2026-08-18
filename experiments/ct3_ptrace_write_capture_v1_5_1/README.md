# CT3 ptrace write capture v1.5.1

Corrects v1.5 by adding Linux `__WALL` to every ptrace `wait4`. This is
required because `shell_di_camera` is a thread in another thread group rather
than a direct child of the tracer. Tracer stderr is also retained in the
summary log. Sensor operations remain the factory `cis live`, read-only
`info`/`regr`, and `cis stop` sequence.
