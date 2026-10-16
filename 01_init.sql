create table apartamentos {
    id SERIAL PRIMARY KEY,
    id_codominio INT FOREIGN KEY REFERENCES condominios(id),




};

create table condominios;
create table moradores;

create table veiculos {
    id SERIAL PRIMARY KEY,
    id_apartamento FOREIGN KEY REFERENCES apartamentos(id)
};

create table visitantes;

create table morador_apartamento {
    id morador INT Foreign Key REFERENCES (moradores(id))


};

create table receitas;

create table denuncias;

create table multas;