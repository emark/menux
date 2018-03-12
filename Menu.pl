#!/usr/bin/env perl 
use Mojolicious::Lite;

use strict;
use warnings;
use utf8;

use DBIx::Custom;
use YAML::XS 'LoadFile';

my $config = LoadFile('config.yaml');

my $dbi = DBIx::Custom->connect(
   dsn => "dbi:mysql:database=$config->{database}",
   user => $config->{user},
   password => $config->{pass},
   option => {mysql_enable_utf8 => 1}
);

get '/' => sub {
	my $c = shift;
  	
	$c->render(template => 'index');
};

get '/daily/' => sub{
	my $c = shift;

	my $result = $dbi->select(
		column => ['docdate'],
		table => 'daily',
		append => ('group by docdate'),
	)->fetch_all;
	
	$c->render(
		items => $result,
	);
};

get '/daily/new/' => sub{
	my $c = shift;

	my $persons = $dbi->select(
		columns => ['id','name'],
		table => 'person',
		where => {flag => 0},
	)->fetch_all;

	my $menus = $dbi->select(
		columns => ['id','name'],
		table => 'menu',
		where => {flag => 0},
	)->fetch_all;

	$c->render(
		template => 'daily_edit',
		persons => $persons,
		menus => $menus,
	);

};

get '/daily/:docdate/' => sub{
	my $c = shift;
	my $docdate = $c->param('docdate');
	my $result = $dbi->select(
		column => ['person_id', 'name', 'close'],
		table => 'daily',
		where => {docdate => $docdate},
		join => ['inner join person on person.id = daily.person_id'],
		append => ('group by person_id, close'),
	)->fetch_all;

	$c->render(
		template => 'daily_docdate',
		items => $result,
	);
};

get '/daily/:docdate/:person_id/close/:close/' => sub{
	my $c = shift;
	my $docdate = $c->param('docdate');
	my $person_id = $c->param('person_id');
	my $close = $c->param('close') ? 0 : 1;

	$dbi->update(
		{close => $close},
		table => 'daily',
		where => {
			docdate => $docdate,
			person_id => $person_id,
		},
	);

	$c->redirect_to("/daily/$docdate/");
};

get '/daily/:docdate/:person_id/delete/' => sub{
	my $c = shift;
	
	$c->render(
		template => 'daily_docdate_person_delete',
	);
};

post '/daily/:docdate/:person_id/delete/' => sub{
	my $c = shift;
	my $docdate = $c->param('docdate');	

	$dbi->delete(
		table => 'daily',
		where => {
			docdate => $docdate,
			person_id => $c->param('person_id'),
		}
	);
	
	$c->redirect_to("/daily/$docdate/");
};

get '/daily/:docdate/order/' => sub{
	my $c = shift;
	
	my $result = $dbi->select(
		column => ['name', 'yield', 'count(1) as pcs'],
		table => 'daily',
		where => {
			docdate => $c->param('docdate'),
		},
		join => ['inner join submenu on submenu.menu_id = daily.menu_id'],
		append => ' and daily.type = submenu.type group by submenu.name, submenu.yield',
	)->fetch_all;

 	$c->render(
		template => 'daily_docdate_order',
		items => $result,
	);
};

get '/daily/:docdate/:person_id/' => sub{
	my $c = shift;
	
	my $result = $dbi->select(
		column => ['submenu.type', 'name', 'yield'],
		table => 'daily',
		where => {
			docdate => $c->param('docdate'),
			person_id => $c->param('person_id'),
		},
		join => ['left join submenu on submenu.menu_id = daily.menu_id'],
		append => ' and daily.type = submenu.type',
	)->fetch_all;
	my $person = $dbi->select(
		column => ['name'],
		table => 'person',
		where => {id => $c->param('person_id')},

	)->value;

	my $types = $dbi->select(
		column => ['type', 'name'],
		table => 'daily',
		where => {
			docdate => $c->param('docdate'),
			person_id => $c->param('person_id'),
		},
		join => ['left join menu on menu.id = daily.menu_id'],

	)->fetch_all;

 	$c->render(
		template => 'daily_docdate_person',
		items => $result,
		person => $person,
		types => $types,
	);
};

post '/daily/new/' => sub{
	my $c = shift;
	my $d = [
		{docdate => $c->param('docdate'), person_id => $c->param('person'), menu_id => $c->param('menu_B'), type => 'B'},
		{docdate => $c->param('docdate'), person_id => $c->param('person'), menu_id => $c->param('menu_L'), type => 'L'},
		{docdate => $c->param('docdate'), person_id => $c->param('person'), menu_id => $c->param('menu_D'), type => 'D'},
	];

	if($c->param('docdate')){
		$dbi->delete(
			table => 'daily',
			where => {
				docdate => $c->param('docdate'),
				person_id => $c->param('person'),
			},
		);
		$dbi->insert(
			$d,
			table => 'daily',
		);
	};

	$c->redirect_to('/daily/');
};

get '/submenu/' => sub{
	my $c = shift;

	my $result = $dbi->select(
		table => 'menu',
	)->fetch_all;
	
	$c->render(
		items => $result,
	);
};

get '/submenu/:menu_id/:type/:id/' => sub{
	my $c = shift;
	my $menu_id = $c->param('menu_id');
	my $type = $c->param('type');
	
	$dbi->delete(
		table => 'submenu',
		where => {id => $c->param('id')},
	);	

	$c->redirect_to("/submenu/$menu_id/$type");
};

any '/submenu/:menu_id/:type/' => sub{
	my $c = shift;
	my $result = '';
	
	if($c->param('name')){
		$result = $dbi->insert(
			{
				name => $c->param('name'),
				yield => $c->param('yield'),
				menu_id => $c->param('menu_id'),
				type => $c->param('type'),
			},
			table => 'submenu',
		);

	};

	$result = $dbi->select(
		column => ['id','name','yield'],
		table => 'submenu',
		where => {
			menu_id => $c->param('menu_id'),
			type => $c->param('type'),
		},
	)->fetch_all;

	$c->render(
		template => 'submenu_menu_type',
		items => $result,
	);
};

get '/:reference/' => sub{
	my $c = shift;
	my $reference = $c->param('reference');
	my $result = $dbi->select(
		table => $reference,
		where => {flag => 0},
  	);
	
	$c->render(
		template => 'reference',
		items => $result->fetch_all,
		reference => $reference
	);
};

get '/:reference/archive/' => sub{
	my $c = shift;
	my $reference = $c->param('reference');
	my $result = $dbi->select(
		table => $reference,
		where => {flag => 1},
  	);
	
	$c->render(
		template => 'reference',
		items => $result->fetch_all,
		reference => $reference
	);
};

get '/:reference/:id/archive/:flag/' => sub{
	my $c = shift;
	my $reference = $c->param('reference');
	my $id = $c->param('id');
	my $flag = $c->param('flag') ? 0 : 1;
	
	my $result = $dbi->update(
			{flag => $flag},
			table => $reference,
			where => {id => $id},
  	) || '';

	$c->redirect_to("/".$reference);
};

get '/:reference/:id/report/' => sub{
	my $c = shift;
	my $reference = $c->param('reference');
	my $id = $c->param('id');
	my %ref_id = (menu => 'menu_id', person => 'person_id');

	my $items = $dbi->select(
		column => ['docdate'],
		table => 'daily',
		where => {$ref_id{$reference} => $id, close => 1},
		append => 'group by docdate',
	)->fetch_all;

	my $ref_name = $dbi->select(
		column => ['name'],
		table => $reference,
		where => {id => $id},
	)->value;
	
	$c->render(
		items => $items,
		template => 'reference_report',
		reference => $reference,
		ref_name => $ref_name,
	);
};

get '/:reference/:id/edit/' => sub{
	my $c = shift;
	my $reference = $c->param('reference');
	my $id = $c->param('id');
	
	my $result = $dbi->select(
			column => ['name'],
			table => $reference,
			where => {id => $id},
  	) || '';

	$c->render(
		template => 'reference_edit',
		name => $result->value,
		reference => $reference,
	);
};

post '/:reference/:id/edit/' => sub{
	my $c = shift;
	
	my $reference = $c->param('reference');
	my $id = $c->param('id');
	my $name = $c->param('name');

	if($id){
	
		$dbi->update(
			{name => $name},
			table => $reference,
			where => {id => $id},
		);

	}else{
		if($c->param('name')){	
			$dbi->insert(
				{name => $name},
				table => $reference,
			);

		};

	};

	$c->redirect_to('/'.$reference);
	
};

get '/:reference/:id/delete/' => sub{
	my $c = shift;
	my $reference = $c->param('reference');
	my $id = $c->param('id');

	$c->render(
		template => 'reference_delete',
		reference => $reference,
	);

};


post '/:reference/:id/delete/' => sub{
	my $c = shift;
	my $reference = $c->param('reference');
	my $id = $c->param('id');

	$dbi->delete(
		table => $reference,
		where => {id => $id},
	);
	
	$c->redirect_to("/".$reference);
};

app->start;

