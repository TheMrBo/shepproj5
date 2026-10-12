const recipes = [
  {id:'ramen',name:'Ramen',category:'Asian food',time:120,rating:'4.9',image:'ramen',ingredients:[['🍜','Noodles'],['🥚','Egg'],['🧅','Onion'],['🍅','Tomato'],['🧂','Seasoning'],['🥬','Greens']],description:'A warming bowl of Japanese-inspired ramen, with springy noodles, a savory broth, and colorful toppings. Comfort food for slow afternoons and cozy evenings.',steps:['Simmer your favorite vegetable broth with garlic and ginger until fragrant.','Cook the noodles according to the package instructions. Boil an egg to your liking.','Pour the broth over the noodles. Add the egg, vegetables, and your favorite toppings.']},
  {id:'pancakes',name:'Pancakes',category:'Breakfast',time:50,rating:'4.6',image:'pancakes',ingredients:[['🌾','Flour'],['🥚','Egg'],['🥛','Milk'],['🧈','Butter'],['🍓','Berries']],description:'A fluffy stack of golden pancakes makes any morning feel a little more special. Finish with fresh berries and a drizzle of maple syrup.',steps:['Whisk 1 cup flour, 1 tablespoon sugar, and 1 teaspoon baking powder.','Stir in 1 egg, ¾ cup milk, and 1 tablespoon melted butter.','Spoon into a warm buttered pan. Flip when bubbles form, then serve with berries.']},
  {id:'salad',name:'Rainbow salad',category:'Asian food',time:20,rating:'4.8',image:'salad',ingredients:[['🥬','Lettuce'],['🥕','Carrot'],['🥒','Cucumber'],['🍋','Lemon'],['🥑','Avocado']],description:'Fresh, crunchy, and full of color. This easy vegetable bowl brings a bright little break to your day with a zesty sesame dressing.',steps:['Wash and chop the lettuce, cucumber, carrot, and avocado.','Whisk lemon juice with olive oil and a little sesame oil.','Toss the vegetables with the dressing and serve right away.']},
  {id:'toast',name:'French toast',category:'Breakfast',time:25,rating:'4.7',image:'toast',ingredients:[['🍞','Bread'],['🥚','Egg'],['🥛','Milk'],['🧈','Butter'],['🍯','Honey']],description:'Crisp edges, a soft middle, and a touch of sweetness. A simple French toast recipe for the kind of breakfast you want to linger over.',steps:['Whisk 2 eggs with ½ cup milk and a pinch of cinnamon.','Dip thick slices of bread into the mixture on both sides.','Cook in a buttered pan until golden on each side. Finish with honey.']}
];
let saved;
try { saved = new Set(JSON.parse(localStorage.getItem('delicious-saved') || '["ramen","salad"]')); } catch { saved = new Set(['ramen','salad']); }
let current = recipes[0], category = 'All', savedOnly = false, activeTab = 'details';
const $ = selector => document.querySelector(selector);
function announce(message) { $('#announcement').textContent = message; }
function toggleSave(id) {
  saved.has(id) ? saved.delete(id) : saved.add(id);
  try { localStorage.setItem('delicious-saved', JSON.stringify([...saved])); } catch {}
  renderCards(); updateSave();
  announce(`${recipes.find(r=>r.id===id).name} ${saved.has(id)?'saved':'removed from saved recipes'}.`);
}
function renderCards() {
  const query = $('#search').value.trim().toLowerCase();
  const filtered = recipes.filter(r=>(category==='All'||r.category===category)&&(!savedOnly||saved.has(r.id))&&(r.name.toLowerCase().includes(query)||r.ingredients.some(i=>i[1].toLowerCase().includes(query))));
  $('#saved-count').textContent = saved.size;
  $('#results-title').textContent = savedOnly ? 'Your collection' : 'Popular right now';
  $('#result-count').textContent = `${filtered.length} recipe${filtered.length===1?'':'s'}`;
  $('#recipe-grid').innerHTML = filtered.length ? filtered.map(r=>`<article class="recipe-card"><button class="card-save" data-save="${r.id}" aria-label="${saved.has(r.id)?'Unsave':'Save'} ${r.name}" aria-pressed="${saved.has(r.id)}">${saved.has(r.id)?'♥':'♡'}</button><button class="recipe-open" data-open="${r.id}" aria-label="View ${r.name} recipe"><img src="assets/${r.image}.webp" alt="Illustrated ${r.name.toLowerCase()}"><span class="recipe-name">${r.name}</span><span class="card-meta">${r.time} min <span><b>★</b> ${r.rating}</span></span></button></article>`).join('') : '<p class="empty">No recipes found.<br>Try another search or category.</p>';
}
function updateSave() { $('#detail-save').textContent = saved.has(current.id)?'♥':'♡'; $('#detail-save').setAttribute('aria-pressed',saved.has(current.id)); $('#detail-save').setAttribute('aria-label',`${saved.has(current.id)?'Unsave':'Save'} ${current.name}`); }
function setTab(tab) {
  activeTab = tab;
  for (const name of ['details','recipe']) { const el=$(`#${name}-tab`);el.classList.toggle('active',tab===name);el.setAttribute('aria-selected',tab===name);el.tabIndex=tab===name?0:-1; }
  $('#tab-content').setAttribute('aria-labelledby',`${tab}-tab`);
  $('#tab-content').innerHTML = tab==='details'?`<p>${current.description}</p>`:`<ol>${current.steps.map(s=>`<li>${s}</li>`).join('')}</ol>`;
  $('#cook-button').innerHTML = tab==='details'?"Let's cook <span aria-hidden='true'>›</span>":"Back to details <span aria-hidden='true'>↶</span>";
}
function selectRecipe(id) {
  current = recipes.find(r=>r.id===id);
  $('#recipe-title').textContent=current.name; $('#detail-image').src=`assets/${current.image}.webp`; $('#detail-image').alt=`Illustration of ${current.name.toLowerCase()}`;
  $('#detail-time').textContent=`◷ ${current.time} min`; $('#detail-rating').textContent=current.rating;
  $('#ingredients').innerHTML=current.ingredients.map(([icon,name])=>`<li title="${name}" aria-label="${name}"><span aria-hidden="true">${icon}</span></li>`).join('');
  updateSave();setTab('details');
}
const scrollTo = selector => $(selector).scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth',block:'start'});
$('#recipe-grid').addEventListener('click',event=>{const save=event.target.closest('[data-save]'),open=event.target.closest('[data-open]');if(save)toggleSave(save.dataset.save);if(open){selectRecipe(open.dataset.open);announce(`${current.name} recipe selected.`);$('#recipe-detail').showModal();}});
$('#search').addEventListener('input',renderCards);
document.querySelectorAll('.category').forEach(button=>button.addEventListener('click',()=>{category=button.dataset.category;document.querySelectorAll('.category').forEach(b=>{b.classList.toggle('active',b===button);b.setAttribute('aria-pressed',b===button);});renderCards();}));
function setView(view) {
  savedOnly = view === 'saved';
  $('#page-title').textContent = savedOnly ? 'Your saved recipes' : 'What sounds delicious?';
  $('.welcome').hidden = savedOnly;
  document.querySelectorAll('[data-view]').forEach(button => {
    const selected = button.dataset.view === view;
    button.classList.toggle('active', selected);
    if (selected) button.setAttribute('aria-current', 'page'); else button.removeAttribute('aria-current');
  });
  renderCards();
}
document.querySelectorAll('[data-view]').forEach(button => button.addEventListener('click', () => setView(button.dataset.view)));
$('.brand').addEventListener('click', event => { event.preventDefault(); setView('discover'); window.scrollTo({top:0}); });
$('#detail-save').addEventListener('click',()=>toggleSave(current.id));
$('#get-started').addEventListener('click',()=>{scrollTo('#recipe-menu');$('#search').focus({preventScroll:true});});
$('#back').addEventListener('click',()=>$('#recipe-detail').close());
$('#recipe-detail').addEventListener('click',event=>{ if(event.target === $('#recipe-detail')) { const r=event.target.getBoundingClientRect(); if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom) event.target.close(); } });
$('#details-tab').addEventListener('click',()=>setTab('details'));$('#recipe-tab').addEventListener('click',()=>setTab('recipe'));
$('.tabs').addEventListener('keydown',e=>{if(['ArrowLeft','ArrowRight','Home','End'].includes(e.key)){e.preventDefault();setTab(e.key==='Home'?'details':e.key==='End'?'recipe':activeTab==='details'?'recipe':'details');$(`#${activeTab}-tab`).focus();}});
$('#cook-button').addEventListener('click',()=>setTab(activeTab==='details'?'recipe':'details'));
renderCards();selectRecipe('ramen');
