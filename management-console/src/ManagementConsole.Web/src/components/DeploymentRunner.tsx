import { useEffect, useRef, useState } from "react";
import { api } from "../api";

export function DeploymentRunner({
  jobId,
  onReset,
}: {
  jobId: string;
  onReset: () => void;
}) {
  const [lines, setLines] = useState<string[]>([]);
  const [state, setState] = useState<string>("Running");
  const [exit, setExit] = useState<number | null>(null);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let cancelled = false;
    let unsub: (() => void) | undefined;
    (async () => {
      const stop = await api.streamLogs(
        jobId,
        (line) => setLines((prev) => [...prev, line]),
        () => {
          api
            .getDeployment(jobId)
            .then((s) => {
              setState(s.state);
              setExit(s.exitCode);
            })
            .catch(() => setState("Unknown"));
        },
      );
      if (cancelled) stop();
      else unsub = stop;
    })();
    return () => {
      cancelled = true;
      unsub?.();
    };
  }, [jobId]);

  useEffect(() => {
    if (boxRef.current) boxRef.current.scrollTop = boxRef.current.scrollHeight;
  }, [lines.length]);

  return (
    <section>
      <h2>Deployment</h2>
      <p className="muted">
        Job <code>{jobId}</code> · state <strong>{state}</strong>
        {exit !== null && <> · exit {exit}</>}
      </p>
      <div className="logs" ref={boxRef}>
        {lines.join("\n")}
      </div>
      <div className="actions">
        <button className="secondary" onClick={onReset}>
          Start another deployment
        </button>
      </div>
    </section>
  );
}
