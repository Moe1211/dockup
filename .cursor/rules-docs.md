# Documentation Directory Rules

## Directory Structure

```
docs/
├── README.md                      # Documentation index
├── comparison-*.md                # Comparison guides (Heroku, Kubernetes, etc.)
├── reddit-post.md                 # Reddit post templates
├── twitter-thread.md              # Twitter/X thread templates
├── devto-article.md              # Dev.to article template
└── awesome-list-submissions.md   # Awesome list submission guide
```

## Documentation Types

### Comparison Guides

- Detailed comparisons with alternatives
- Feature matrices
- Use case recommendations
- Migration guides
- Decision frameworks

**Files:**

- `comparison-heroku.md` - DockUp vs Heroku
- `comparison-kubernetes.md` - DockUp vs Kubernetes
- `comparison-selfhosted-paas.md` - DockUp vs other self-hosted PaaS

**Structure:**

- Quick comparison table
- Detailed feature comparison
- Cost analysis
- When to use each
- Migration guides
- Use case examples

### Content Templates

- Ready-to-use social media content
- Blog post templates
- Platform-specific messaging

**Files:**

- `reddit-post.md` - Reddit post templates for multiple subreddits
- `twitter-thread.md` - Twitter/X thread templates
- `devto-article.md` - Complete Dev.to article

**Guidelines:**

- Include multiple variations
- Provide customization instructions
- Include best practices
- Add engagement tips

### Submission Guides

- How-to guides for submitting to platforms
- Step-by-step instructions
- Templates and checklists

**Files:**

- `awesome-list-submissions.md` - Guide for awesome list submissions

**Structure:**

- Target lists
- Submission format
- Step-by-step process
- Best practices
- Tracking templates

## Documentation Standards

### File Naming

- Use lowercase with hyphens: `comparison-heroku.md`
- Be descriptive and specific
- Use consistent naming patterns
- Prefix comparison files: `comparison-*.md`
- Use descriptive names for templates: `reddit-post.md`, `twitter-thread.md`

### Content Structure

**Comparison Guides:**

1. Title (h1)
2. Quick comparison table
3. Detailed comparison sections
4. Cost analysis
5. When to use each
6. Migration guides
7. Use case examples
8. Conclusion
9. Resources

**Content Templates:**

1. Title (h1)
2. Platform description
3. Ready-to-use templates
4. Customization instructions
5. Best practices
6. Engagement tips
7. Follow-up strategies

**Submission Guides:**

1. Title (h1)
2. Target platforms
3. Submission format
4. Step-by-step process
5. Best practices
6. Tracking templates
7. Resources

### Code Examples

- Always include complete, working examples
- Show expected output
- Include error handling
- Add comments for clarity
- Test all examples before committing
- Use proper syntax highlighting

### Tables

- Use comparison tables for features
- Include checkmarks (✅) and X marks (❌)
- Use consistent formatting
- Make tables readable and scannable

### Links

- Use relative paths for internal links: `[README](../README.md)`
- Use absolute URLs for external links
- Link to related documents in `social/awareness/`
- Verify all links work

## Maintenance

### Review Process

- Review comparison guides when features change
- Update templates based on platform changes
- Remove outdated information
- Add new examples for new features
- Update submission guides when processes change

### Versioning

- Note DockUp version compatibility in comparisons
- Update comparisons when new features are added
- Keep templates current with platform best practices
- Archive outdated templates if needed

## DockUp-Specific

### Required Documentation

- `README.md` - Documentation index
- `comparison-*.md` - Comparison guides (at least 3)
- `reddit-post.md` - Reddit post templates
- `twitter-thread.md` - Twitter thread templates
- `devto-article.md` - Dev.to article template
- `awesome-list-submissions.md` - Submission guide

### Documentation Updates

- Update comparison guides when features are added
- Update templates based on feedback
- Add new comparison guides for new alternatives
- Update submission guides when processes change
- Keep all docs in sync with main documentation

### Content Guidelines

**Comparison Guides:**

- Be fair and honest about limitations
- Highlight DockUp's strengths
- Acknowledge when alternatives are better suited
- Include real-world use cases
- Provide migration paths

**Content Templates:**

- Make templates ready-to-use
- Include customization instructions
- Provide multiple variations
- Include best practices
- Add engagement strategies

**Submission Guides:**

- Provide step-by-step instructions
- Include templates and checklists
- Add best practices
- Include tracking methods
- Keep submission formats current

### Cross-References

- Link to main docs: `[README](../README.md)`
- Link to social content: `[social/awareness/](../social/awareness/)`
- Link to marketing: `[MARKETING.md](../MARKETING.md)`
- Link to launch checklist: `[LAUNCH_CHECKLIST.md](../LAUNCH_CHECKLIST.md)`

### Style Guidelines

- Use consistent formatting across all comparison guides
- Keep templates authentic and helpful
- Write in developer-friendly language
- Be transparent about limitations
- Focus on solving real problems
