from .database import Movie, db

def get_all(title=None):
    if title:
        return Movie.query.filter(Movie.title.ilike(f"%{title}%")).all()
    return Movie.query.all()


def get_by_id(movie_id):
    return db.session.get(Movie, movie_id)


def create(title, description):
    movie = Movie(title=title, description=description)
    db.session.add(movie)
    db.session.commit()
    return movie


def update(movie, title=None, description=None):
    if title is not None:
        movie.title = title
    if description is not None:
        movie.description = description

    db.session.commit()
    return movie


def delete(movie):
    db.session.delete(movie)
    db.session.commit()


def delete_all():
    deleted_count = Movie.query.delete()
    db.session.commit()
    return deleted_count
