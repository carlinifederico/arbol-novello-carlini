-- ============================================================================
-- 0009 — ORIGIN: compartir una rama, y que los aportes hagan crecer el árbol
--
-- Tres cosas que el esquema todavía no sabía hacer:
--
--   1. COMPARTIR UN PEDAZO. Hoy un miembro ve el árbol entero o nada. Hace
--      falta poder decir «te comparto desde Luigi para atrás» y que el que
--      entra vea esa rama COMO SI FUERA EL ÁRBOL COMPLETO: no debería enterarse
--      de que existe una rama siciliana, ni de que hay gente viva del otro lado.
--
--   2. QUE EL APORTE SEA UNA PROPUESTA CONCRETA, no un texto libre. «Elda se
--      casó con Marcelo Durán en 1948» tiene que llegar como algo que la app
--      pueda ESCRIBIR SOLA al aprobarlo. Si llega como párrafo, alguien tiene
--      que releerlo y tipearlo, que es exactamente lo que hay que evitar.
--
--   3. APROBAR = ESCRIBIR. Una función que toma la propuesta y crea las
--      personas, los vínculos y las aserciones que correspondan, dejando
--      registrado quién lo aportó y quién lo aprobó.
-- ============================================================================

-- ---------- 1. compartir una rama ----------
create type share_scope as enum ('whole', 'ancestors', 'descendants', 'both');

create table shares (
  id           uuid primary key default gen_random_uuid(),
  tree_id      uuid not null references trees on delete cascade,
  -- desde quién se comparte. null = el árbol entero
  focus_id     uuid,
  scope        share_scope not null default 'ancestors',
  -- hasta dónde: 4 generaciones, 6, todas. null = sin límite
  max_depth    smallint,
  hide_living  boolean not null default false,
  can_contribute boolean not null default true,
  -- el link. Se guarda el hash, nunca el token: el token vive sólo en el link
  token_hash   text not null unique,
  label        text,
  note         text,          -- "te comparto la rama de tu abuelo"
  expires_at   timestamptz,
  revoked_at   timestamptz,
  created_by   uuid not null references auth.users,
  created_at   timestamptz not null default now(),
  foreign key (focus_id, tree_id) references persons(id, tree_id) on delete cascade
);
create index on shares (tree_id) where revoked_at is null;
alter table shares enable row level security;

create policy shares_all on shares for all to authenticated
  using ((select app.can_write(tree_id))) with check ((select app.can_write(tree_id)));

/* Quiénes entran en una rama compartida.
   Recursivo, con corte por profundidad. El `visited` evita que un ciclo mal
   cargado cuelgue la consulta: el esquema ya prohíbe ciclos con un trigger,
   pero una función que recorre un grafo no debería confiar en eso. */
create or replace function app.alcance_share(p_share uuid)
returns table (person_id uuid)
language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare s shares;
begin
  select * into s from shares where id = p_share;
  if not found or s.revoked_at is not null
     or (s.expires_at is not null and s.expires_at < now()) then
    return;
  end if;

  if s.focus_id is null or s.scope = 'whole' then
    return query select p.id from persons p where p.tree_id = s.tree_id;
    return;
  end if;

  return query
  with recursive camino as (
    select s.focus_id as id, 0 as nivel, array[s.focus_id] as visited
    union all
    select
      case when s.scope in ('ancestors','both') then pc.parent_id else pc.child_id end,
      c.nivel + 1,
      c.visited || case when s.scope in ('ancestors','both') then pc.parent_id else pc.child_id end
    from camino c
    join parent_child pc
      on (s.scope in ('ancestors','both') and pc.child_id = c.id)
      or (s.scope in ('descendants','both') and pc.parent_id = c.id)
    where (s.max_depth is null or c.nivel < s.max_depth)
      and not (case when s.scope in ('ancestors','both') then pc.parent_id else pc.child_id end = any(c.visited))
      and pc.tree_id = s.tree_id
  )
  select distinct id from camino where id is not null;
end $fn$;

-- ---------- 2. el aporte como propuesta ----------
/* `payload` describe qué se propone, en una forma que approve_contribution
   sepa escribir. Ejemplos:
     {"tipo":"union","persona":"eldaCarlini","conyuge":{"nombre":"Marcelo Durán"},
      "fecha":"1948"}
     {"tipo":"hijo","padre":"eldaCarlini","nombre":"…","nacimiento":"…"}
     {"tipo":"dato","persona":"luigi","campo":"occupation","valor":"mecánico"}
   Se valida al aprobar, no al recibir: el que aporta no tiene por qué conocer
   el esquema, y rechazarle el aporte por un campo mal puesto sería perderlo. */
alter table contributions add column if not exists payload jsonb;
alter table contributions add column if not exists share_id uuid references shares(id) on delete set null;
alter table contributions add column if not exists applied_ids jsonb;

comment on column contributions.payload is
  'Qué se propone, en forma que approve_contribution pueda escribir. Se valida al aprobar, no al recibir.';
comment on column contributions.applied_ids is
  'Qué escribió la aprobación. Permite deshacerla sin adivinar.';

-- ---------- 3. aprobar escribe en el árbol ----------
create or replace function approve_contribution(p_id uuid, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare
  c contributions; d jsonb; hechos jsonb := '[]'::jsonb;
  v_persona uuid; v_nueva uuid; v_union uuid; v_quien text;
begin
  select * into c from contributions where id = p_id;
  if not found then raise exception 'no existe ese aporte'; end if;
  if not app.can_write(c.tree_id) then raise exception 'sin permiso'; end if;
  if c.status = 'approved' then raise exception 'ese aporte ya fue aprobado'; end if;

  d := coalesce(c.payload, '{}'::jsonb);
  v_quien := 'Aportado por ' || c.submitted_email ||
             coalesce(', procedencia: ' || c.provenance, '');

  -- a quién se refiere: por id directo o por la clave legible del árbol
  v_persona := c.person_id;
  if v_persona is null and d ? 'persona' then
    select id into v_persona from persons
     where tree_id = c.tree_id and gedcom_xref = (d->>'persona');
  end if;

  if d->>'tipo' in ('union','hijo','padre') then
    -- la persona que se agrega
    insert into persons (tree_id, sex, display_name, sort_name,
                         existence_confidence, notes, created_by)
    values (c.tree_id, coalesce(d->'nuevo'->>'sexo','U')::sex_type,
            coalesce(d->'nuevo'->>'nombre', d->>'conyuge', c.title),
            lower(coalesce(d->'nuevo'->>'nombre', c.title)),
            'unconfirmed', v_quien, auth.uid())
    returning id into v_nueva;
    hechos := hechos || jsonb_build_object('persons', v_nueva);

    if d->>'tipo' = 'union' and v_persona is not null then
      insert into unions (tree_id, kind, confidence, created_by)
      values (c.tree_id, 'marriage', 'unconfirmed', auth.uid())
      returning id into v_union;
      insert into union_partners (tree_id, union_id, person_id, seq)
      values (c.tree_id, v_union, v_persona, 1), (c.tree_id, v_union, v_nueva, 2);
      hechos := hechos || jsonb_build_object('unions', v_union);
      if d ? 'fecha' then
        insert into assertions (tree_id, kind, union_id, date_text, date_modifier,
                                confidence, rationale, created_by)
        values (c.tree_id, 'marriage', v_union, d->>'fecha', 'unknown',
                'unconfirmed', v_quien, auth.uid());
      end if;
    elsif d->>'tipo' = 'hijo' and v_persona is not null then
      insert into parent_child (tree_id, parent_id, child_id, kind, confidence)
      values (c.tree_id, v_persona, v_nueva, 'biological', 'unconfirmed');
    elsif d->>'tipo' = 'padre' and v_persona is not null then
      insert into parent_child (tree_id, parent_id, child_id, kind, confidence)
      values (c.tree_id, v_nueva, v_persona, 'biological', 'unconfirmed');
    end if;

  elsif d->>'tipo' = 'dato' and v_persona is not null then
    insert into assertions (tree_id, kind, person_id, value_text, date_text,
                            date_modifier, confidence, rationale, created_by)
    values (c.tree_id, coalesce(d->>'campo','other')::assertion_kind, v_persona,
            d->>'valor', d->>'fecha', 'unknown', 'unconfirmed', v_quien, auth.uid());
  end if;

  /* Siempre queda además una entrada de investigación: un aporte aprobado dice
     «esto es real y sirve», no «esto ya está verificado». Lo que entró al árbol
     entra con confianza `unconfirmed` y con el nombre de quien lo aportó. */
  insert into research_items (tree_id, person_id, title, body, status, priority, created_by)
  values (c.tree_id, coalesce(v_persona, c.person_id),
          'Verificar aporte: ' || c.title,
          coalesce(c.body,'') || E'\n\n' || v_quien,
          'open', 2, auth.uid());

  update contributions
     set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now(),
         review_note = p_note, applied_ids = hechos
   where id = p_id;

  return hechos;
end $fn$;
revoke all on function approve_contribution(uuid, text) from public;
grant execute on function approve_contribution(uuid, text) to authenticated;
