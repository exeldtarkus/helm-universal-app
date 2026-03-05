import express from 'express';
import { exec } from 'child_process';
import util from 'util';

// Promisify exec agar bisa menggunakan async/await dengan bersih
const execPromise = util.promisify(exec);

const app = express();
app.use(express.json());

app.get('/', (req, res) => {
  return res.status(200).json({ message: 'k8s - API - Deploy is Healthy' });
});

app.post('/deploy', async (req, res) => {
  const { image, namespace = 'production' } = req.body;

  // Validasi payload
  if (!image || !image.includes(':')) {
    return res.status(400).json({ 
      error: 'Format image tidak valid. Wajib menyertakan repository dan tag (contoh: repo/app:v1)' 
    });
  }

  try {
    const [repo, tag] = image.split(':');

    const cmd = `helm upgrade --install universal-app /charts/universal-app \
      --namespace ${namespace} \
      --create-namespace \
      --set image.repository=${repo} \
      --set image.tag=${tag}`;

    console.log(`[DEPLOY - START] Executing in namespace '${namespace}' for image '${image}'...`);

    const { stdout, stderr } = await execPromise(cmd);

    // Helm terkadang menulis warning ke stderr meskipun command sukses
    if (stderr) {
      console.warn(`[DEPLOY - WARNING] ${stderr.trim()}`);
    }

    console.log(`[DEPLOY - SUCCESS] Deployment terpicu untuk ${image}`);
    
    res.status(200).json({ 
      status: 'success', 
      image,
      namespace,
      message: 'Helm upgrade executed successfully',
      helmOutput: stdout.trim() 
    });

  } catch (err) {
    console.error(`[DEPLOY - ERROR] Failed to deploy:`, err.message);
    const helmErrorDetails = err.stderr ? err.stderr.trim() : err.message;
    
    res.status(500).json({ 
      error: 'Helm deployment failed', 
      details: helmErrorDetails 
    });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Deploy API running on port ${PORT}`);
});