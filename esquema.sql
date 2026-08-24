-- Esquema completo del arbol familiar, en un solo archivo.
-- Pegar entero en el SQL Editor de Supabase y darle Run. Es todo o nada:
-- si algo falla, la transaccion vuelve atras y no queda medio esquema.
-- Las migraciones 0004 y 0005 son semillas viejas de cuando el arbol tenia
-- 63 personas: quedan obsoletas, las reemplaza scripts/import-datos.mjs.
-- Generado el 24-ago-2026.

begin;


-- ========================= 0001_core_schema.sql =========================
-- ============================================================
-- 0001 — Núcleo: extensiones, enums, tenencia, personas, relaciones, lugares
-- ============================================================
create extension if not exists pgcrypto;
create extension if not exists citext;
create extension if not exists pg_trgm;
create extension if not exists unaccent;

-- ---------- Enums ----------
-- orden deliberado viewer < editor < owner: permite greatest() al aceptar invitaciones
create type tree_role      as enum ('viewer','editor','owner');
create type sex_type       as enum ('M','F','X','U');
create type confidence     as enum ('disproven','unconfirmed','low','normal','high','proven');
create type date_modifier  as enum ('exact','about','before','after','between','calculated','estimated','unknown');
create type union_kind     as enum ('marriage','religious_marriage','civil_union','partnership','unknown');
create type union_status   as enum ('active','ended_death','ended_divorce','ended_annulment','ended_separation','unknown');
create type parent_kind    as enum ('biological','adoptive','step','foster','presumed','unknown');
create type assertion_kind as enum ('name','birth','baptism','death','burial','marriage','divorce','residence',
                                    'occupation','nationality','citizenship','immigration','emigration',
                                    'education','military','religion','physical','other');
create type document_kind  as enum ('birth_act','baptism_act','marriage_act','death_act','burial_act',
                                    'id_card','passport','citizenship_file','court_ruling','notarial_act',
                                    'census','military_record','ship_manifest','translation','apostille',
                                    'legalization','photo','letter','obituary','family_note','other');
create type doc_relation   as enum ('translation_of','apostille_of','legalization_of','certified_copy_of',
                                    'extract_of','page_of','supersedes','cited_by');
create type doc_person_role as enum ('subject','spouse','father','mother','child','sibling','witness',
                                     'declarant','informant','official','godparent','translator','mentioned');

-- ---------- Tenencia ----------
create table profiles (
  user_id      uuid primary key references auth.users on delete cascade,
  email        citext not null,
  display_name text,
  avatar_url   text,
  locale       text not null default 'es',
  created_at   timestamptz not null default now()
);

create table trees (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  description    text,
  root_person_id uuid,
  created_by     uuid not null references auth.users,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table tree_members (
  tree_id          uuid not null references trees on delete cascade,
  user_id          uuid not null references auth.users on delete cascade,
  role             tree_role not null default 'viewer',
  linked_person_id uuid,
  added_by         uuid references auth.users,
  created_at       timestamptz not null default now(),
  primary key (tree_id, user_id)
);
create index on tree_members (user_id);

create table invitations (
  id          uuid primary key default gen_random_uuid(),
  tree_id     uuid not null references trees on delete cascade,
  email       citext not null,
  role        tree_role not null default 'viewer',
  token_hash  text not null unique,
  message     text,
  invited_by  uuid not null references auth.users,
  expires_at  timestamptz not null default now() + interval '14 days',
  accepted_at timestamptz,
  accepted_by uuid references auth.users,
  revoked_at  timestamptz,
  created_at  timestamptz not null default now()
);
create unique index invitations_pending_uq on invitations (tree_id, email)
  where accepted_at is null and revoked_at is null;

-- ---------- Lugares ----------
create table places (
  id           uuid primary key default gen_random_uuid(),
  tree_id      uuid not null references trees on delete cascade,
  name         text not null,
  parent_id    uuid references places(id),
  kind         text,
  country_code text,
  lat          double precision,
  lon          double precision,
  aliases      text[],
  full_path    text,
  unique (id, tree_id)
);
create index on places (tree_id, name);

-- ---------- Personas ----------
create table persons (
  id                    uuid primary key default gen_random_uuid(),
  tree_id               uuid not null references trees on delete cascade,
  sex                   sex_type not null default 'U',
  existence_confidence  confidence not null default 'normal',
  is_living             boolean,
  gedcom_xref           text,
  notes                 text,
  merged_into_id        uuid references persons(id),
  -- caché derivada, mantenida por trigger. NUNCA fuente de verdad.
  display_name          text,
  sort_name             text,
  birth_year            smallint,
  death_year            smallint,
  primary_photo_file_id uuid,
  created_by uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (id, tree_id)
);
create index on persons (tree_id, sort_name);
create index persons_sort_name_trgm on persons using gin (sort_name gin_trgm_ops);

alter table trees add constraint trees_root_person_fk
  foreign key (root_person_id) references persons(id) on delete set null;
alter table tree_members add constraint tree_members_person_fk
  foreign key (linked_person_id) references persons(id) on delete set null;

create table person_names (
  id         uuid primary key default gen_random_uuid(),
  tree_id    uuid not null,
  person_id  uuid not null,
  name_type  text not null default 'birth',
  given      text,
  particle   text,   -- 'de', 'De' separado: "De Faccio" y "de Faccio" son el mismo nombre
  surname    text,
  suffix     text,
  language   text,
  is_primary boolean not null default false,
  confidence confidence not null default 'normal',
  normalized text,
  notes      text,
  foreign key (person_id, tree_id) references persons(id, tree_id) on delete cascade
);
create unique index person_names_one_primary on person_names (person_id) where is_primary;
create index person_names_norm_trgm on person_names using gin (normalized gin_trgm_ops);

-- Equivalencias entre idiomas. El matching por trigramas jamás uniría Luigi con Luis.
create table name_equivalences (
  root text not null, variant text not null, lang text,
  primary key (root, variant)
);
insert into name_equivalences (root, variant, lang) values
 ('giovanni','juan','es'), ('giovanni','john','en'), ('giovanni','zuan','fur'), ('giovanni','gianni','it'),
 ('giovanni battista','juan bautista','es'), ('giovanni battista','giobatta','it'), ('giovanni battista','gio batta','it'),
 ('luigi','luis','es'), ('luigi','louis','fr'), ('luigi','gigi','it'),
 ('giuseppe','jose','es'), ('giuseppe','joseph','en'), ('giuseppe','bepi','it'),
 ('santa','santina','it'), ('annibale','anibal','es'), ('pietro','pedro','es'),
 ('francesco','francisco','es'), ('domenica','menega','fur'), ('bartolomeo','bortolo','fur'),
 ('biagia','blasia','fur'), ('carlo','carlos','es'), ('antonio','antonino','it')
on conflict do nothing;

-- ---------- Relaciones: modelo híbrido (unión + arista explícita) ----------
create table unions (
  id          uuid primary key default gen_random_uuid(),
  tree_id     uuid not null references trees on delete cascade,
  kind        union_kind not null default 'unknown',
  status      union_status not null default 'unknown',
  confidence  confidence not null default 'normal',
  gedcom_xref text,
  notes       text,
  created_by uuid,
  created_at timestamptz default now(),
  unique (id, tree_id)
);

create table union_partners (
  union_id   uuid not null,
  person_id  uuid not null,
  tree_id    uuid not null,
  role       text not null default 'partner',
  seq        smallint not null default 1,
  confidence confidence not null default 'normal',
  primary key (union_id, person_id),
  foreign key (union_id, tree_id)  references unions(id, tree_id)  on delete cascade,
  foreign key (person_id, tree_id) references persons(id, tree_id) on delete cascade
);

create table parent_child (
  id                   uuid primary key default gen_random_uuid(),
  tree_id              uuid not null,
  parent_id            uuid not null,
  child_id             uuid not null,
  union_id             uuid,
  kind                 parent_kind not null default 'biological',
  confidence           confidence not null default 'normal',
  birth_order          smallint,
  multiple_birth_group uuid,   -- mellizos comparten valor
  notes                text,
  unique (parent_id, child_id),
  check (parent_id <> child_id),
  foreign key (parent_id, tree_id) references persons(id, tree_id) on delete cascade,
  foreign key (child_id,  tree_id) references persons(id, tree_id) on delete cascade,
  foreign key (union_id,  tree_id) references unions(id, tree_id)  on delete set null
);
create index on parent_child (tree_id, child_id);
create index on parent_child (tree_id, parent_id);
create index on parent_child (union_id);

-- Sin ciclos: nadie puede ser su propio antepasado (si no, el layout entra en loop infinito)
create or replace function prevent_pc_cycle() returns trigger
language plpgsql as $fn$
begin
  if exists (
    with recursive up(id) as (
      select new.parent_id
      union
      select pc.parent_id from parent_child pc join up on pc.child_id = up.id
    ) select 1 from up where id = new.child_id
  ) then
    raise exception 'ciclo genealogico: % ya es descendiente de %', new.parent_id, new.child_id;
  end if;
  return new;
end
$fn$;

create trigger parent_child_no_cycle before insert or update on parent_child
  for each row execute function prevent_pc_cycle();


-- ========================= 0002_documents_and_assertions.sql =========================
-- ============================================================
-- 0002 — Bóveda documental, evidencia (aserciones), adjudicación, auditoría
-- Principio: una persona no tiene datos propios. Tiene aserciones con fuente.
-- ============================================================

-- ---------- Documentos ----------
create table documents (
  id                 uuid primary key default gen_random_uuid(),
  tree_id            uuid not null references trees on delete cascade,
  kind               document_kind not null,
  title              text not null,
  language           text,
  issued_modifier    date_modifier not null default 'exact',
  issued_earliest    date,
  issued_latest      date,
  issued_text        text,
  issuing_authority  text,
  place_id           uuid references places(id),
  -- coordenadas de cita estructuradas -> "Latisana 1929, Nati, Parte I, n. 130"
  archive            text,
  collection         text,
  register_series    text,
  register_year      smallint,
  volume             text,
  act_number         text,
  folio              text,
  external_ref       text,
  citation_label     text,
  transcription      text,
  ocr_text           text,
  search_tsv         tsvector,
  is_certified       boolean default false,
  notes              text,
  gedcom_xref        text,
  created_by uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (id, tree_id)
);
create index documents_tsv on documents using gin (search_tsv);
create index on documents (tree_id, kind);

create table document_files (
  id           uuid primary key default gen_random_uuid(),
  tree_id      uuid not null,
  document_id  uuid not null,
  storage_path text not null unique,   -- <tree_id>/<document_id>/<file_id>.<ext>
  thumb_path   text,
  page_no      smallint,
  label        text,
  mime_type    text not null,
  byte_size    bigint,
  sha256       text,
  status       text not null default 'pending',
  uploaded_by  uuid,
  created_at timestamptz default now(),
  foreign key (document_id, tree_id) references documents(id, tree_id) on delete cascade
);

-- Las traducciones juradas y apostillas son documentos SEPARADOS, vinculados al original
create table document_relations (
  from_document_id uuid not null,
  to_document_id   uuid not null,
  tree_id          uuid not null,
  relation         doc_relation not null,
  notes            text,
  primary key (from_document_id, to_document_id, relation),
  check (from_document_id <> to_document_id),
  foreign key (from_document_id, tree_id) references documents(id, tree_id) on delete cascade,
  foreign key (to_document_id,   tree_id) references documents(id, tree_id) on delete cascade
);

-- Un acta de matrimonio genera 6 filas: novia, novio y los cuatro padres
create table document_persons (
  document_id     uuid not null,
  person_id       uuid not null,
  tree_id         uuid not null,
  role            doc_person_role not null default 'subject',
  name_as_written text,   -- la grafía exacta de ESE documento
  age_as_written  text,
  notes           text,
  primary key (document_id, person_id, role),
  foreign key (document_id, tree_id) references documents(id, tree_id) on delete cascade,
  foreign key (person_id,   tree_id) references persons(id, tree_id)   on delete cascade
);
create index on document_persons (person_id);

-- ---------- Aserciones: hechos con fuente, conflictos permitidos ----------
create table assertions (
  id              uuid primary key default gen_random_uuid(),
  tree_id         uuid not null references trees on delete cascade,
  kind            assertion_kind not null,
  person_id       uuid,
  union_id        uuid,
  parent_child_id uuid,
  check (num_nonnulls(person_id, union_id, parent_child_id) = 1),
  -- fecha estructurada, mapeable 1:1 a GEDCOM
  date_modifier   date_modifier not null default 'exact',
  date_earliest   date,
  date_latest     date,
  date_text       text,       -- textual: "ventotto luglio millenovecentoventinove"
  place_id        uuid references places(id),
  place_text      text,       -- tal cual figura en el acta
  value_text      text,       -- oficio, nacionalidad, causa de muerte, nombre...
  detail          jsonb,
  confidence      confidence not null default 'normal',
  is_preferred    boolean not null default false,
  disputed        boolean not null default false,
  rationale       text,
  created_by uuid,
  created_at timestamptz default now(),
  foreign key (person_id, tree_id) references persons(id, tree_id) on delete cascade,
  foreign key (union_id,  tree_id) references unions(id, tree_id)  on delete cascade
);
-- Una sola preferida para hechos singulares. residence/occupation/name son multivaluados a propósito.
create unique index assertions_pref_person on assertions (person_id, kind)
  where is_preferred and person_id is not null
    and kind in ('birth','death','baptism','burial');
create unique index assertions_pref_union on assertions (union_id, kind)
  where is_preferred and union_id is not null
    and kind in ('marriage','divorce');
create index on assertions (tree_id, person_id, kind);

create table assertion_sources (
  assertion_id    uuid not null references assertions(id) on delete cascade,
  document_id     uuid not null,
  tree_id         uuid not null,
  citation_detail text,
  page_no         smallint,
  quote           text,
  supports        boolean not null default true,  -- false = este documento CONTRADICE
  primary key (assertion_id, document_id),
  foreign key (document_id, tree_id) references documents(id, tree_id) on delete cascade
);

create view assertion_conflicts as
select tree_id, person_id, union_id, kind,
       count(*) as n_variants,
       count(*) filter (where is_preferred) as n_preferred,
       jsonb_agg(jsonb_build_object('id',id,'date',date_earliest,'place',place_text,
                                    'value',value_text,'confidence',confidence,
                                    'preferred',is_preferred,'disputed',disputed)) as variants
from assertions
where kind in ('birth','death','marriage','baptism','burial')
group by tree_id, person_id, union_id, kind
having count(distinct coalesce(date_earliest::text,'') || '|' ||
                      coalesce(place_text,'')          || '|' ||
                      coalesce(value_text,'')) > 1;

-- Log de decisiones, append-only. La justificación es obligatoria.
create table adjudications (
  id                  uuid primary key default gen_random_uuid(),
  tree_id             uuid not null references trees on delete cascade,
  subject_person_id   uuid,
  subject_union_id    uuid,
  kind                assertion_kind not null,
  chosen_assertion_id uuid not null references assertions(id) on delete cascade,
  rationale           text not null,
  status              text not null default 'resolved',
  decided_by          uuid not null references auth.users,
  decided_at          timestamptz not null default now()
);

create or replace function apply_adjudication() returns trigger
language plpgsql as $fn$
declare a assertions%rowtype;
begin
  select * into a from assertions where id = new.chosen_assertion_id;
  update assertions set is_preferred = false
   where kind = a.kind
     and ((a.person_id is not null and person_id = a.person_id)
       or (a.union_id  is not null and union_id  = a.union_id));
  update assertions set is_preferred = true where id = new.chosen_assertion_id;
  return new;
end
$fn$;
create trigger adjudication_applies after insert on adjudications
  for each row execute function apply_adjudication();

-- ---------- Preguntas abiertas de investigación ----------
create table research_items (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null references trees on delete cascade,
  person_id uuid, union_id uuid, document_id uuid,
  title text not null,
  body text,
  status text not null default 'open',
  priority smallint default 2,
  assigned_to uuid references auth.users,
  created_by uuid,
  created_at timestamptz default now(),
  resolved_at timestamptz
);

-- ---------- Auditoría ----------
create table audit_log (
  id bigint generated always as identity primary key,
  tree_id uuid not null,
  table_name text not null,
  -- nullable a propósito: union_partners, document_persons, document_relations y
  -- assertion_sources tienen clave primaria compuesta y no tienen columna id.
  row_id uuid,
  op char(1) not null,
  actor uuid default auth.uid(),
  diff jsonb,
  at timestamptz not null default now()
);
create index on audit_log (tree_id, at desc);
create index on audit_log (row_id);

create or replace function audit_trigger() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_diff jsonb;
begin
  v_diff := to_jsonb(case when tg_op = 'DELETE' then old else new end);
  insert into audit_log (tree_id, table_name, row_id, op, diff)
  values ((v_diff ->> 'tree_id')::uuid, tg_table_name,
          (v_diff ->> 'id')::uuid,      -- null si la tabla no tiene columna id
          left(tg_op, 1), v_diff);
  return coalesce(new, old);
end
$fn$;

-- ---------- Caché derivada de persons ----------
create or replace function recompute_person_cache(p_person uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_name text; v_sort text; v_b smallint; v_d smallint;
begin
  select trim(both ' ' from concat_ws(' ', n.given, n.particle, n.surname)),
         lower(unaccent(concat_ws(' ', n.surname, n.given)))
    into v_name, v_sort
  from person_names n
  where n.person_id = p_person
  order by n.is_primary desc, n.name_type = 'birth' desc
  limit 1;

  select extract(year from a.date_earliest)::smallint into v_b
  from assertions a where a.person_id = p_person and a.kind = 'birth'
  order by a.is_preferred desc, a.confidence desc limit 1;

  select extract(year from a.date_earliest)::smallint into v_d
  from assertions a where a.person_id = p_person and a.kind = 'death'
  order by a.is_preferred desc, a.confidence desc limit 1;

  update persons
     set display_name = coalesce(v_name, display_name),
         sort_name    = coalesce(v_sort, sort_name),
         birth_year   = v_b,
         death_year   = v_d,
         updated_at   = now()
   where id = p_person;
end
$fn$;

create or replace function touch_person_cache() returns trigger
language plpgsql as $fn$
declare v_person uuid;
begin
  -- En plpgsql NEW queda NULL en un DELETE y OLD queda NULL en un INSERT: el coalesce
  -- cubre los tres casos. (En una cláusula WHEN de trigger esto NO sería válido:
  -- Postgres prohíbe referenciar NEW en DELETE y OLD en INSERT.)
  if tg_op = 'DELETE' then v_person := old.person_id; else v_person := new.person_id; end if;
  if v_person is not null then
    perform recompute_person_cache(v_person);
  end if;
  return coalesce(new, old);
end
$fn$;

create trigger person_names_cache after insert or update or delete on person_names
  for each row execute function touch_person_cache();
create trigger assertions_cache after insert or update or delete on assertions
  for each row execute function touch_person_cache();

-- Normalización de nombres para búsqueda
create or replace function normalize_person_name() returns trigger
language plpgsql as $fn$
begin
  new.normalized := lower(unaccent(concat_ws(' ', new.given, new.particle, new.surname)));
  return new;
end
$fn$;
create trigger person_names_normalize before insert or update on person_names
  for each row execute function normalize_person_name();

-- Etiqueta de cita generada
create or replace function build_citation_label() returns trigger
language plpgsql as $fn$
begin
  if new.citation_label is null then
    new.citation_label := nullif(trim(concat_ws(', ',
      new.archive, new.collection, new.register_series,
      nullif(new.register_year::text,''),
      case when new.act_number is not null then 'n. ' || new.act_number end)), '');
  end if;
  new.search_tsv := to_tsvector('simple',
    coalesce(new.title,'') || ' ' || coalesce(new.transcription,'') || ' ' ||
    coalesce(new.ocr_text,'') || ' ' || coalesce(new.citation_label,''));
  return new;
end
$fn$;
create trigger documents_citation before insert or update on documents
  for each row execute function build_citation_label();


-- ========================= 0003_rls_and_storage.sql =========================
-- ============================================================
-- 0003 — RLS, storage, invitaciones, RPC del grafo
-- ============================================================
create schema if not exists app;

-- Los security definer NO son opcionales: una policy sobre tree_members que consulte
-- tree_members entra en recursión infinita. La función definer rompe el ciclo.
create or replace function app.is_member(p_tree uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $fn$
  select exists (select 1 from tree_members where tree_id = p_tree and user_id = auth.uid())
$fn$;

create or replace function app.can_write(p_tree uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $fn$
  select exists (select 1 from tree_members
                 where tree_id = p_tree and user_id = auth.uid() and role in ('owner','editor'))
$fn$;

create or replace function app.is_owner(p_tree uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $fn$
  select exists (select 1 from tree_members
                 where tree_id = p_tree and user_id = auth.uid() and role = 'owner')
$fn$;

revoke all on function app.is_member(uuid), app.can_write(uuid), app.is_owner(uuid) from public;
grant execute on function app.is_member(uuid), app.can_write(uuid), app.is_owner(uuid) to authenticated;

-- ---------- Generación de policies ----------
-- Escribir 4 policies a mano por cada una de 14 tablas es donde nacen los bugs de seguridad.
-- El (select ...) hace que Postgres evalúe UNA vez por query, no una por fila.
do $gen$
declare t text;
begin
  foreach t in array array[
    'places','persons','person_names','unions','union_partners','parent_child',
    'documents','document_files','document_relations','document_persons',
    'assertions','assertion_sources','research_items'
  ] loop
    execute format('alter table %I enable row level security', t);
    execute format($p$create policy %1$s_select on %1$I for select to authenticated
                     using ((select app.is_member(tree_id)))$p$, t);
    execute format($p$create policy %1$s_insert on %1$I for insert to authenticated
                     with check ((select app.can_write(tree_id)))$p$, t);
    execute format($p$create policy %1$s_update on %1$I for update to authenticated
                     using ((select app.can_write(tree_id)))
                     with check ((select app.can_write(tree_id)))$p$, t);
    execute format($p$create policy %1$s_delete on %1$I for delete to authenticated
                     using ((select app.can_write(tree_id)))$p$, t);
    -- auditoría
    execute format('create trigger %I after insert or update or delete on %I
                    for each row execute function audit_trigger()', t || '_audit', t);
  end loop;
end
$gen$;

-- ---------- Policies específicas ----------
alter table trees enable row level security;
create policy trees_select on trees for select to authenticated
  using ((select app.is_member(id)));
create policy trees_insert on trees for insert to authenticated
  with check (created_by = auth.uid());
create policy trees_update on trees for update to authenticated
  using ((select app.is_owner(id))) with check ((select app.is_owner(id)));
create policy trees_delete on trees for delete to authenticated
  using ((select app.is_owner(id)));

alter table tree_members enable row level security;
create policy tm_select on tree_members for select to authenticated
  using ((select app.is_member(tree_id)));
create policy tm_update on tree_members for update to authenticated
  using ((select app.is_owner(tree_id)));
create policy tm_delete on tree_members for delete to authenticated
  using ((select app.is_owner(tree_id)) or user_id = auth.uid());
-- sin policy de INSERT a propósito: sólo vía trigger o RPC

alter table invitations enable row level security;
create policy inv_select on invitations for select to authenticated
  using ((select app.can_write(tree_id)) or email = auth.email());
create policy inv_insert on invitations for insert to authenticated
  with check ((select app.can_write(tree_id)));
create policy inv_update on invitations for update to authenticated
  using ((select app.can_write(tree_id)));
create policy inv_delete on invitations for delete to authenticated
  using ((select app.is_owner(tree_id)));

-- El hash del token nunca llega a un cliente, ni siquiera a uno autorizado a leer la fila
revoke select on invitations from authenticated;
grant select (id, tree_id, email, role, message, invited_by,
              expires_at, accepted_at, revoked_at, created_at) on invitations to authenticated;

alter table adjudications enable row level security;
create policy adj_select on adjudications for select to authenticated
  using ((select app.is_member(tree_id)));
create policy adj_insert on adjudications for insert to authenticated
  with check ((select app.can_write(tree_id)));
-- sin update: append-only

alter table audit_log enable row level security;
create policy audit_select on audit_log for select to authenticated
  using ((select app.is_member(tree_id)));

alter table profiles enable row level security;
create policy prof_self on profiles for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table name_equivalences enable row level security;
create policy nameeq_read on name_equivalences for select to authenticated using (true);

-- ---------- Guardas ----------
-- El creador queda owner por trigger. Nunca dejar que lo haga el cliente.
create or replace function trees_add_owner() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $fn$
begin
  insert into tree_members (tree_id, user_id, role, added_by)
  values (new.id, new.created_by, 'owner', new.created_by);
  return new;
end
$fn$;
create trigger trees_owner after insert on trees
  for each row execute function trees_add_owner();

-- No dejar el árbol sin dueño
create or replace function protect_last_owner() returns trigger
language plpgsql as $fn$
begin
  if old.role = 'owner' and (tg_op = 'DELETE' or new.role <> 'owner') then
    if (select count(*) from tree_members
        where tree_id = old.tree_id and role = 'owner') <= 1 then
      raise exception 'no se puede quitar el ultimo owner del arbol';
    end if;
  end if;
  return coalesce(new, old);
end
$fn$;
create trigger tm_last_owner before update or delete on tree_members
  for each row execute function protect_last_owner();

-- Un editor sólo puede invitar viewers
create or replace function guard_invite_role() returns trigger
language plpgsql as $fn$
begin
  if new.role in ('owner','editor') and not app.is_owner(new.tree_id) then
    raise exception 'solo un owner puede invitar con rol %', new.role;
  end if;
  return new;
end
$fn$;
create trigger inv_role_guard before insert or update on invitations
  for each row execute function guard_invite_role();

-- ---------- Invitaciones ----------
create or replace function create_invitation(p_tree uuid, p_email text, p_role tree_role, p_message text)
returns text language plpgsql security definer set search_path = public, pg_temp, extensions as $fn$
declare v_token text;
begin
  if not app.can_write(p_tree) then raise exception 'sin permiso'; end if;
  v_token := encode(gen_random_bytes(32), 'hex');
  insert into invitations (tree_id, email, role, token_hash, message, invited_by)
  values (p_tree, p_email, p_role, encode(digest(v_token,'sha256'),'hex'), p_message, auth.uid())
  on conflict (tree_id, email) where accepted_at is null and revoked_at is null
  do update set token_hash = excluded.token_hash,
                role = excluded.role,
                expires_at = now() + interval '14 days';
  return v_token;   -- el token en crudo sólo existe acá y en el email
end
$fn$;

create or replace function accept_invitation(p_token text)
returns uuid language plpgsql security definer set search_path = public, pg_temp, extensions as $fn$
declare v invitations%rowtype;
begin
  select * into v from invitations
   where token_hash = encode(digest(p_token,'sha256'),'hex')
     and accepted_at is null and revoked_at is null and expires_at > now()
   for update;
  if not found then
    raise exception 'invitacion invalida o vencida' using errcode = 'P0001';
  end if;
  -- La propiedad de seguridad que importa: un link reenviado no sirve.
  if lower(v.email::text) <> lower(coalesce(auth.email(), '')) then
    raise exception 'esta invitacion es para otra cuenta' using errcode = 'P0002';
  end if;
  insert into tree_members (tree_id, user_id, role, added_by)
  values (v.tree_id, auth.uid(), v.role, v.invited_by)
  on conflict (tree_id, user_id) do update
    set role = greatest(tree_members.role, excluded.role);
  update invitations set accepted_at = now(), accepted_by = auth.uid() where id = v.id;
  return v.tree_id;
end
$fn$;

revoke all on function create_invitation(uuid, text, tree_role, text) from public;
revoke all on function accept_invitation(text) from public;
grant execute on function create_invitation(uuid, text, tree_role, text) to authenticated;
grant execute on function accept_invitation(text) to authenticated;

-- ---------- Perfil automático al registrarse con Google ----------
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $fn$
begin
  insert into profiles (user_id, email, display_name, avatar_url)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
          new.raw_user_meta_data->>'avatar_url')
  on conflict (user_id) do nothing;
  return new;
end
$fn$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- ---------- Storage ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documents','documents', false, 52428800,
        array['application/pdf','image/jpeg','image/png','image/heic','image/tiff','image/webp'])
on conflict (id) do nothing;

-- Un cast que lanza excepción dentro de una policy devuelve 500, no deniega.
-- Devolver null hace que is_member(null) sea false, que deniega limpio.
create or replace function app.path_tree(p_name text) returns uuid
language sql immutable as $fn$
  select case when (storage.foldername(p_name))[1]
                 ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then ((storage.foldername(p_name))[1])::uuid end
$fn$;

create policy documents_read on storage.objects for select to authenticated
  using (bucket_id = 'documents' and (select app.is_member(app.path_tree(name))));
create policy documents_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'documents' and (select app.can_write(app.path_tree(name))));
create policy documents_update on storage.objects for update to authenticated
  using (bucket_id = 'documents' and (select app.can_write(app.path_tree(name))));
create policy documents_delete on storage.objects for delete to authenticated
  using (bucket_id = 'documents' and (select app.can_write(app.path_tree(name))));

-- ---------- RPC del grafo: un solo round-trip alimenta todo el canvas ----------
create or replace function get_tree_graph(p_tree uuid) returns jsonb
language sql stable security invoker set search_path = public as $fn$
  select jsonb_build_object(
    'persons', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.display_name, 'sex', p.sex,
        'birthYear', p.birth_year, 'deathYear', p.death_year,
        'confidence', p.existence_confidence,
        'docCount', (select count(*) from document_persons dp where dp.person_id = p.id),
        'hasConflict', exists (select 1 from assertion_conflicts c where c.person_id = p.id)
      ) order by p.birth_year nulls last)
      from persons p where p.tree_id = p_tree and p.merged_into_id is null
    ), '[]'::jsonb),
    'unions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', u.id, 'kind', u.kind, 'status', u.status, 'confidence', u.confidence,
        'year', (select extract(year from a.date_earliest)::int from assertions a
                  where a.union_id = u.id and a.kind = 'marriage'
                  order by a.is_preferred desc limit 1),
        'partnerIds', (select coalesce(jsonb_agg(up.person_id order by up.seq), '[]'::jsonb)
                        from union_partners up where up.union_id = u.id)
      ))
      from unions u where u.tree_id = p_tree
    ), '[]'::jsonb),
    'edges', coalesce((
      select jsonb_agg(jsonb_build_object(
        'parentId', pc.parent_id, 'childId', pc.child_id, 'unionId', pc.union_id,
        'kind', pc.kind, 'confidence', pc.confidence, 'twinGroup', pc.multiple_birth_group
      ))
      from parent_child pc where pc.tree_id = p_tree
    ), '[]'::jsonb)
  )
$fn$;
grant execute on function get_tree_graph(uuid) to authenticated;


-- ========================= 0006_public_and_contributions.sql =========================
-- ============================================================================
-- 0006 — Árbol público con aportes moderados
--
-- Tres cosas, y el orden importa:
--
--   1. Un árbol puede marcarse PÚBLICO. Eso abre la LECTURA a cualquiera, con
--      o sin cuenta: personas, nombres, parentescos, hechos y la FICHA de cada
--      documento. Nunca los archivos.
--
--   2. Los ESCANEOS DE PERSONAS VIVAS no se abren nunca al público, ni en un
--      árbol público. Un acta de nacimiento lleva datos de terceros —padres,
--      testigos, domicilios— que no eligieron estar ahí. Se ve QUÉ documento
--      existe y dónde está; el archivo sólo lo abren los miembros.
--
--   3. Cualquiera con cuenta de Google —sin invitación— puede APORTAR material.
--      Los aportes caen en una bandeja y no tocan el árbol hasta que un editor
--      los aprueba. Que haya que entrar con Google no es burocracia: ata cada
--      aporte a un email, y sin eso no hay a quién repreguntarle de dónde salió
--      una foto, que es justo lo que hace falta en genealogía.
-- ============================================================================

-- ---------- 1. la marca de público ----------
alter table trees add column if not exists is_public boolean not null default false;
alter table trees add column if not exists public_slug text unique;
alter table trees add column if not exists public_intro text;

comment on column trees.is_public is
  'Abre la lectura a anónimos. Los archivos de personas vivas siguen cerrados.';

create or replace function app.is_public(p_tree uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from trees t where t.id = p_tree and t.is_public);
$$;

-- ¿Este árbol lo puede LEER quien está pidiendo? Miembro, o árbol público.
create or replace function app.can_read(p_tree uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select app.is_public(p_tree) or app.is_member(p_tree);
$$;

-- ---------- 2. lectura pública de los datos, no de los archivos ----------
-- El rol `anon` entra sólo por estas policies. Se listan una por una a
-- propósito: una tabla que no esté acá NO se abre, y agregar una tabla nueva
-- al esquema no la publica por accidente.
do $$
declare t text;
begin
  foreach t in array array[
    'persons','person_names','unions','union_partners','parent_child','places',
    'documents','document_persons','document_relations','assertions','assertion_sources'
  ] loop
    execute format($p$
      drop policy if exists %1$s_public_select on %1$I;
      create policy %1$s_public_select on %1$I for select to anon
        using ((select app.is_public(tree_id)));
    $p$, t);
  end loop;
end $$;

-- Los archivos NO. document_files queda fuera de la lista de arriba y además
-- se le pone una policy explícita para anónimos que sólo deja ver los de
-- personas que no están vivas.
drop policy if exists document_files_public_select on document_files;
create policy document_files_public_select on document_files for select to anon
  using (
    (select app.is_public(tree_id))
    and not exists (
      select 1 from document_persons dp
      join persons p on p.id = dp.person_id
      where dp.document_id = document_files.document_id
        and coalesce(p.is_living, false)
    )
  );

-- Y lo mismo en el bucket: un anónimo no baja el archivo de alguien vivo.
drop policy if exists documents_public_read on storage.objects;
create policy documents_public_read on storage.objects for select to anon
  using (
    bucket_id = 'documents'
    and (select app.is_public(app.path_tree(name)))
    and exists (
      select 1 from document_files f
      where f.storage_path = storage.objects.name
        and not exists (
          select 1 from document_persons dp
          join persons p on p.id = dp.person_id
          where dp.document_id = f.document_id and coalesce(p.is_living, false)
        )
    )
  );

-- ---------- 3. los aportes ----------
create type contribution_kind as enum
  ('photo','document','testimony','correction','person','other');
create type contribution_status as enum
  ('pending','approved','rejected','merged');

create table contributions (
  id           uuid primary key default gen_random_uuid(),
  tree_id      uuid not null references trees on delete cascade,
  kind         contribution_kind not null default 'other',
  -- a quién se refiere: puede ser nadie todavía
  person_id    uuid,
  person_hint  text,          -- "el hermano de mi abuela, creo que Luis"
  title        text not null,
  body         text,
  -- de dónde sale: en genealogía la procedencia vale tanto como el dato
  provenance   text,          -- "estaba en el álbum de mi mamá, Mar del Plata"
  contact      text,          -- si quiere dejar otro contacto además del mail
  status       contribution_status not null default 'pending',
  submitted_by uuid not null references auth.users on delete cascade,
  submitted_email citext not null,
  reviewed_by  uuid references auth.users,
  reviewed_at  timestamptz,
  review_note  text,
  created_at   timestamptz not null default now(),
  foreign key (person_id, tree_id) references persons(id, tree_id) on delete set null
);
create index on contributions (tree_id, status, created_at desc);
create index on contributions (submitted_by);

create table contribution_files (
  id           uuid primary key default gen_random_uuid(),
  contribution_id uuid not null references contributions on delete cascade,
  storage_path text not null unique,   -- aportes/<tree_id>/<contribution_id>/<file>
  mime_type    text not null,
  byte_size    bigint,
  created_at   timestamptz not null default now()
);
create index on contribution_files (contribution_id);

alter table contributions enable row level security;
alter table contribution_files enable row level security;

-- Aportar: cualquiera logueado, sobre un árbol público, y sólo a nombre propio.
create policy contrib_insert on contributions for insert to authenticated
  with check (
    (select app.is_public(tree_id))
    and submitted_by = (select auth.uid())
    and status = 'pending'
  );

-- Ver: el que lo mandó ve el suyo; los miembros del árbol ven todos.
create policy contrib_select on contributions for select to authenticated
  using (submitted_by = (select auth.uid()) or (select app.is_member(tree_id)));

-- Moderar: sólo quien puede escribir en el árbol.
create policy contrib_update on contributions for update to authenticated
  using ((select app.can_write(tree_id))) with check ((select app.can_write(tree_id)));
create policy contrib_delete on contributions for delete to authenticated
  using ((select app.is_owner(tree_id)) or submitted_by = (select auth.uid()));

create policy contribfiles_all on contribution_files for select to authenticated
  using (exists (select 1 from contributions c where c.id = contribution_id
                 and (c.submitted_by = (select auth.uid()) or (select app.is_member(c.tree_id)))));
create policy contribfiles_insert on contribution_files for insert to authenticated
  with check (exists (select 1 from contributions c where c.id = contribution_id
                      and c.submitted_by = (select auth.uid()) and c.status = 'pending'));

-- Bucket aparte. Privado: lo que aporta un desconocido no se publica solo.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('aportes','aportes', false, 26214400,
        array['image/jpeg','image/png','image/heic','image/tiff','application/pdf'])
on conflict (id) do nothing;

create policy aportes_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'aportes' and (select app.is_public(app.path_tree(name))));
create policy aportes_read on storage.objects for select to authenticated
  using (bucket_id = 'aportes' and (select app.is_member(app.path_tree(name))));

-- ---------- aprobar un aporte ----------
-- Mueve el aporte a research_items para que quede en la cola de trabajo, y lo
-- marca. NO escribe personas ni fechas en el árbol: eso lo decide un humano
-- mirando la evidencia. Un aporte aprobado quiere decir «esto es real y sirve»,
-- no «esto ya es un hecho del árbol».
create or replace function approve_contribution(p_id uuid, p_note text default null)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare c contributions; r uuid;
begin
  select * into c from contributions where id = p_id;
  if not found then raise exception 'no existe ese aporte'; end if;
  if not app.can_write(c.tree_id) then raise exception 'sin permiso'; end if;

  update contributions
     set status = 'approved', reviewed_by = auth.uid(),
         reviewed_at = now(), review_note = p_note
   where id = p_id;

  insert into research_items (tree_id, person_id, title, body, status, priority, created_by)
  values (c.tree_id, c.person_id,
          'Aporte: ' || c.title,
          coalesce(c.body,'') ||
            case when c.provenance is not null
                 then E'\n\nProcedencia: ' || c.provenance else '' end ||
            E'\n\nLo mandó: ' || c.submitted_email,
          'open', 2, auth.uid())
  returning id into r;
  return r;
end $$;
revoke all on function approve_contribution(uuid, text) from public;
grant execute on function approve_contribution(uuid, text) to authenticated;


commit;
