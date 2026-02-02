
import { motion } from 'framer-motion'

export default function App() {
  return (
    <div style={{ padding: 16, fontFamily: 'system-ui' }}>
      <h1>🥬 StillFresh</h1>
      <p>MVP running. Scan flow coming next.</p>
      <motion.div
        animate={{ opacity: [0, 1] }}
        transition={{ duration: 0.8 }}
        style={{ marginTop: 24 }}
      >
        <button style={{ padding: 12, fontSize: 16 }}>
          Scan Receipt
        </button>
      </motion.div>
    </div>
  )
}
