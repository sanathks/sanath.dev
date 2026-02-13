/**
 * Remark plugin to render D2 diagrams at build time
 * 
 * Usage in markdown:
 * ```d2
 * direction: down
 * a -> b -> c
 * ```
 * 
 * Options:
 * ```d2 theme=light sketch=true
 * a -> b
 * ```
 */

import { visit } from 'unist-util-visit';
import { execSync } from 'child_process';
import { writeFileSync, readFileSync, mkdirSync, existsSync, unlinkSync } from 'fs';
import { join } from 'path';
import { createHash } from 'crypto';

// D2 binary path
const D2_BIN = process.env.D2_BIN || `${process.env.HOME}/.local/bin/d2`;

// Theme configurations matching sanath.dev color scheme
const THEMES = {
  light: {
    id: 0, // Neutral default
    vars: `
      vars: {
        d2-config: {
          theme-id: 0
        }
      }
    `
  },
  dark: {
    id: 200, // Dark Mauve
    vars: `
      vars: {
        d2-config: {
          theme-id: 200
        }
      }
    `
  }
};

function hashContent(content) {
  return createHash('md5').update(content).digest('hex').slice(0, 8);
}

function renderD2(code, options = {}) {
  const { animate = false, sketch = false } = options;
  const hash = hashContent(code);
  const tempDir = '/tmp/d2-diagrams';
  
  if (!existsSync(tempDir)) {
    mkdirSync(tempDir, { recursive: true });
  }

  const results = {};
  
  for (const [themeName, themeConfig] of Object.entries(THEMES)) {
    const inputFile = join(tempDir, `${hash}-${themeName}.d2`);
    const outputFile = join(tempDir, `${hash}-${themeName}.svg`);
    
    // Prepend theme config to code
    const themedCode = `${themeConfig.vars}\n${code}`;
    writeFileSync(inputFile, themedCode);
    
    try {
      const args = [
        `--theme=${themeConfig.id}`,
        sketch ? '--sketch' : '',
        animate ? '--animate-interval=1500' : '',
        inputFile,
        outputFile
      ].filter(Boolean).join(' ');
      
      execSync(`${D2_BIN} ${args}`, { 
        stdio: 'pipe',
        timeout: 30000 
      });
      
      let svg = readFileSync(outputFile, 'utf-8');
      
      // Clean up temp files
      unlinkSync(inputFile);
      unlinkSync(outputFile);
      
      // Remove XML declaration and make SVG responsive
      svg = svg
        .replace(/<\?xml[^>]*\?>/, '')
        .replace(/width="\d+"/, 'width="100%"')
        .replace(/height="\d+"/, 'height="auto"');
      
      results[themeName] = svg;
    } catch (error) {
      console.error(`D2 render error (${themeName}):`, error.message);
      results[themeName] = `<pre class="d2-error">D2 Error: ${error.message}</pre>`;
    }
  }
  
  return results;
}

function parseOptions(meta) {
  const options = {};
  if (!meta) return options;
  
  const pairs = meta.split(/\s+/);
  for (const pair of pairs) {
    if (pair.includes('=')) {
      const [key, value] = pair.split('=');
      options[key] = value === 'true' ? true : value === 'false' ? false : value;
    } else if (pair === 'animate') {
      options.animate = true;
    } else if (pair === 'sketch') {
      options.sketch = true;
    }
  }
  return options;
}

export default function remarkD2() {
  return (tree) => {
    visit(tree, 'code', (node, index, parent) => {
      if (node.lang !== 'd2') return;
      
      const options = parseOptions(node.meta);
      const { light: lightSvg, dark: darkSvg } = renderD2(node.value, options);
      
      // Create HTML node with theme-switching SVGs
      const html = `
<figure class="d2-diagram my-8 not-prose">
  <div class="d2-light block dark:hidden">
    ${lightSvg}
  </div>
  <div class="d2-dark hidden dark:block">
    ${darkSvg}
  </div>
</figure>`;
      
      // Replace code block with rendered HTML
      parent.children[index] = {
        type: 'html',
        value: html
      };
    });
  };
}
