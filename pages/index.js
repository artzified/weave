import Link from "@docusaurus/Link";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";
import Layout from "@theme/Layout";
import CodeBlock from "@theme/CodeBlock";
import { useEffect, useRef } from "react";
import styles from "./index.module.css";

// ─── Thread canvas ────────────────────────────────────────────────────────────

function ThreadCanvas() {
  const canvasRef = useRef(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas.getContext("2d");
    let raf;

    const resize = () => {
      canvas.width = canvas.offsetWidth;
      canvas.height = canvas.offsetHeight;
    };
    resize();
    window.addEventListener("resize", resize);

    const THREAD_COUNT = 12;
    const threads = Array.from({ length: THREAD_COUNT }, (_, i) => ({
      y: ((i + 0.5) / THREAD_COUNT) * canvas.height,
      particles: Array.from({ length: 50 }, () => ({
        x: Math.random() * canvas.width,
        speed: 0.4 + Math.random() * 1.0,
        opacity: Math.random(),
        size: 1 + Math.random() * 1.5,
      })),
      hue: 38 + (i % 3) * 4,
    }));

    const tick = () => {
      // Read theme on every frame so switching is instant with no React re-render
      const isDark = document.documentElement.dataset.theme === "dark";
      // Light mode needs darker, more saturated particles to be visible on white
      const lightness = isDark ? 60 : 32;
      const lineOpacity = isDark ? 0.06 : 0.12;
      const particleOpacity = isDark ? 0.55 : 0.7;

      ctx.clearRect(0, 0, canvas.width, canvas.height);
      for (const thread of threads) {
        ctx.beginPath();
        ctx.moveTo(0, thread.y);
        ctx.lineTo(canvas.width, thread.y);
        ctx.strokeStyle = `hsla(${thread.hue}, 80%, ${lightness}%, ${lineOpacity})`;
        ctx.lineWidth = 1;
        ctx.stroke();

        for (const p of thread.particles) {
          p.x += p.speed;
          if (p.x > canvas.width) {
            p.x = 0;
            p.opacity = Math.random();
          }
          p.opacity = Math.max(
            0,
            Math.min(1, p.opacity + (Math.random() - 0.5) * 0.04),
          );
          ctx.beginPath();
          ctx.arc(p.x, thread.y, p.size, 0, Math.PI * 2);
          ctx.fillStyle = `hsla(${thread.hue}, 90%, ${lightness}%, ${p.opacity * particleOpacity})`;
          ctx.fill();
        }
      }
      raf = requestAnimationFrame(tick);
    };
    tick();

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
    };
  }, []);

  return <canvas ref={canvasRef} className={styles.threadCanvas} />;
}

// ─── Features ─────────────────────────────────────────────────────────────────

const FEATURES = [
  {
    title: "No Frame Drops",
    description:
      "Your game loop keeps rendering and simulating while workers crunch in the background. You get to keep the frame budget for smoother gameplay.",
  },
  {
    title: "Fire and Forget",
    description:
      "Use DispatchDetached when you only care about side effects: terrain writes, physics updates, state mutations. No result buffer allocated, no callback, no overhead.",
  },
  {
    title: "Optimal Routing",
    description:
      "Batching and work distribution are handled automatically. Add more actors and the same dispatch call spreads thinner slices across more cores.",
  },
  {
    title: "Minimal Setup",
    description:
      "Register handlers with :On or :OnDetached, call :Ready, and weave wires everything else. No boilerplate, no manual actor management.",
  },
];

function FeatureCard({ title, description }) {
  return (
    <div className={styles.featureCard}>
      <h3 className={styles.featureTitle}>{title}</h3>
      <p className={styles.featureDesc}>{description}</p>
    </div>
  );
}

// ─── Code panes ───────────────────────────────────────────────────────────────
// CodeBlock from @theme/CodeBlock uses Prism under the hood — syntax
// highlighting, light/dark mode, and theme consistency all handled for free.

const WORKER_CODE = `local kernel = weave.kernel.new(actor)

-- register a handler that returns results
kernel:On("sweep", function(id)
  return workspace:Raycast(
    origins[id], directions[id]
  )
end)

-- register a fire-and-forget handler
kernel:OnDetached("update", function(id)
  simulateParticle(id, dt)
end)

kernel:Ready()`;

const MASTER_CODE = `local dispatcher = weave.dispatcher.new(
  16, script.Parent.worker
)

-- results collected, callback fires when done
dispatcher:Dispatch("sweep", 10000,
  function(buf)
    processSweepResults(buf)
  end
)

-- no callback, no allocation, no waiting
dispatcher:DispatchDetached("update", 10000)`;

function CodePane({ label, code }) {
  return (
    <div className={styles.codePane}>
      {/* title prop renders the filename bar in CodeBlock */}
      <CodeBlock language="lua" title={label} className={styles.codePaneBlock}>
        {code}
      </CodeBlock>
    </div>
  );
}

// ─── Sections ─────────────────────────────────────────────────────────────────

function Hero() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <header className={styles.hero}>
      <ThreadCanvas />
      <div className={styles.heroInner}>
        <div className={styles.heroBadge}>0.10.0-beta.1</div>
        <h1 className={styles.heroTitle}>{siteConfig.title}</h1>
        <p className={styles.heroTagline}>
          {siteConfig.tagline}
        </p>
        <div className={styles.heroCta}>
          <Link className="button button--primary button--lg" to="/docs/intro">
            Get Started
          </Link>
          <Link className="button button--secondary button--lg" to="/docs/api">
            API Reference
          </Link>
        </div>
      </div>
    </header>
  );
}

function CodeSection() {
  return (
    <section className={styles.codeSection}>
      <div className={styles.sectionInner}>
        <p className={styles.eyebrow}>Usage</p>
        <h2 className={styles.sectionTitle}>
          Kernel does the work. Dispatcher decides how.
        </h2>
        <p className={styles.sectionSub}>
          Workers use the kernel to declare what they can do. The dispatcher
          decides when and how many threads to run. weave handles batching,
          routing, and result aggregation for you.
        </p>
        <div className={styles.codePanes}>
          <CodePane label="worker.luau" code={WORKER_CODE} />
          <CodePane label="master.luau" code={MASTER_CODE} />
        </div>
      </div>
    </section>
  );
}

function FeaturesSection() {
  return (
    <section className={styles.featuresSection}>
      <div className={styles.sectionInner}>
        <p className={styles.eyebrow}>Why weave</p>
        <h2 className={styles.sectionTitle}>
          Parallelism, but we took the headache out of it
        </h2>
        <div className={styles.featuresGrid}>
          {FEATURES.map((f) => (
            <FeatureCard key={f.title} {...f} />
          ))}
        </div>
      </div>
    </section>
  );
}

export default function Home() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout title={siteConfig.title} description={siteConfig.tagline}>
      <Hero />
      <main>
        <CodeSection />
        <FeaturesSection />
      </main>
    </Layout>
  );
}
