import fs from 'fs';
import postcss from 'postcss';

const cssPath = 'src/pages/LandingPage.css';
let css = fs.readFileSync(cssPath, 'utf8');

// First, undo the broken regex replaces from earlier
css = css.replace(/\.landing-page-wrapper \*,/g, '*,');
css = css.replace(/\.landing-page-wrapper \*::before,/g, '*::before,');
css = css.replace(/\.landing-page-wrapper \*::after \{/g, '*::after {');
css = css.replace(/\.landing-page-wrapper nav \{/g, 'nav {');
css = css.replace(/\.landing-page-wrapper footer \{/g, 'footer {');
css = css.replace(/\.landing-page-wrapper section \{/g, 'section {');
css = css.replace(/\.landing-page-wrapper a \{/g, 'a {');
css = css.replace(/\.section-\.landing-page-wrapper \{/g, '.section-body {');

// Remove the inline !important I added earlier to avoid issues
css = css.replace(/font-family: var\(--sans\) !important;/g, 'font-family: var(--sans);');
css = css.replace(/background-color: var\(--paper\) !important;/g, 'background-color: var(--paper);');
css = css.replace(/color: var\(--ink\) !important;/g, 'color: var(--ink);');
css = css.replace(/position: absolute;[\s\S]*?z-index: 9999;/g, '');

const plugin = postcss.plugin('scope', (options) => {
  return (root) => {
    root.walkRules((rule) => {
      if (rule.parent && rule.parent.type === 'atrule' && rule.parent.name === 'keyframes') {
        return;
      }
      
      const selectors = rule.selectors.map(selector => {
        // Skip if already scoped
        if (selector.includes('.landing-page-wrapper')) {
          return selector;
        }
        
        // Scope html, body, :root to .landing-page-wrapper
        if (selector === 'html' || selector === 'body' || selector === ':root') {
          return '.landing-page-wrapper';
        }
        
        return `.landing-page-wrapper ${selector}`;
      });
      
      rule.selectors = selectors;
    });
  };
});

postcss([plugin])
  .process(css, { from: cssPath, to: cssPath })
  .then(result => {
    fs.writeFileSync(cssPath, result.css);
    console.log('CSS scoped successfully!');
  });
