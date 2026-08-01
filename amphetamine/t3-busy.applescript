-- T3 Busy: a marker application that does nothing but exist.
--
-- Amphetamine's app trigger watches for this bundle; bin/t3_awake launches and
-- terminates it as T3 Code turn activity starts and stops. The long idle return
-- keeps wakeups negligible.

on run
end run

on idle
	return 3600
end idle
