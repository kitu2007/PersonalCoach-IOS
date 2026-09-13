"use client";

import { useMemo, useState } from "react";

type Mode = "dump" | "now" | "focus" | "stuck";

const reasons = ["I can't start", "I'm anxious", "It's overwhelming", "I got distracted", "I'm frustrated", "Low energy"];

export default function Home() {
  const [mode, setMode] = useState<Mode>("dump");
  const [dump, setDump] = useState("");
  const [task, setTask] = useState("Open the document and write 3 rough bullets");
  const [minutes, setMinutes] = useState(10);
  const [seconds, setSeconds] = useState(600);
  const [running, setRunning] = useState(false);

  useMemo(() => {
    if (!running || seconds <= 0) return;
    const id = window.setTimeout(() => setSeconds((s) => s - 1), 1000);
    return () => window.clearTimeout(id);
  }, [running, seconds]);

  function chooseForMe() {
    const first = dump.split(/[.!?\n]/).map(s => s.trim()).find(Boolean);
    if (first) setTask(`Spend 10 minutes making a rough start on: ${first}`);
    setMode("now");
  }

  function startFocus() {
    setSeconds(minutes * 60);
    setRunning(true);
    setMode("focus");
  }

  return (
    <main className="shell">
      <header><div className="brand">Personal Coach</div><div className="quiet">No guilt. Just the next step.</div></header>

      {mode === "dump" && <section className="card hero">
        <p className="eyebrow">BRAIN DUMP</p>
        <h1>What's on your mind?</h1>
        <p>Don't organize it. Don't prioritize it. Just get it out of your head.</p>
        <textarea autoFocus value={dump} onChange={e => setDump(e.target.value)} placeholder="I need to finish the research summary, reply to…" />
        <button className="primary" disabled={!dump.trim()} onClick={chooseForMe}>Choose for me</button>
      </section>}

      {mode === "now" && <section className="card hero">
        <p className="eyebrow">RIGHT NOW</p>
        <h1>{task}</h1>
        <p>You do not need to finish it. You only need to start.</p>
        <div className="chips">{[5,10,20].map(m => <button key={m} className={minutes===m?"chip active":"chip"} onClick={()=>setMinutes(m)}>{m} min</button>)}</div>
        <button className="primary" onClick={startFocus}>Start</button>
        <button className="link" onClick={()=>setMode("stuck")}>I'm stuck</button>
      </section>}

      {mode === "focus" && <section className="card hero center">
        <p className="eyebrow">FOCUS</p>
        <div className="timer">{String(Math.floor(seconds/60)).padStart(2,"0")}:{String(seconds%60).padStart(2,"0")}</div>
        <h2>{task}</h2>
        <p>Nothing else matters until this timer ends.</p>
        <button className="secondary" onClick={()=>setRunning(!running)}>{running?"Pause":"Continue"}</button>
        <button className="link" onClick={()=>{setRunning(false);setMode("stuck")}}>I got distracted / I'm stuck</button>
        <button className="link" onClick={()=>{setRunning(false);setDump("");setMode("dump")}}>Done</button>
      </section>}

      {mode === "stuck" && <section className="card">
        <p className="eyebrow">NO PROBLEM</p>
        <h1>What's getting in the way?</h1>
        <p>No explanation required. Pick the closest one.</p>
        <div className="reasons">{reasons.map(r => <button key={r} onClick={()=>{setTask(r.includes("overwhelm")||r.includes("anxious") ? "Take one minute. Then open only the file you need—nothing else." : "Do the smallest visible piece for just 5 minutes");setMinutes(5);setMode("now")}}>{r}</button>)}</div>
        <button className="link" onClick={()=>setMode("now")}>Back</button>
      </section>}

      <footer>This prototype intentionally hides backlogs, streaks, scores and overdue warnings.</footer>
    </main>
  );
}
