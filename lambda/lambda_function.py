import boto3
import re
import requests
from bs4 import BeautifulSoup, Tag
from typing import TypedDict, List, Literal

db_client = boto3.client('dynamodb')


class Post(TypedDict):
    price: int
    address: str
    term: Literal['Fall', 'Winter', 'Spring']
    type: Literal['Coed', 'Male Only', 'Female Only']


def parse_raw_post(raw_post: Tag, raw_post_attribute: Tag) -> Post:
    # TODO: check for efficiency
    # TODO: Better way than using next()? Prolly still O(n)
    # TODO: How to extract link? Will I have to use Selenium? :O
    try:
        post: Post = dict()
        post['price'] = next(int(s) for s in raw_post.strings if s.isnumeric())
        post['address'] = next(s.strip()
                               for s in raw_post.strings if 'Waterloo' in s)
        post['term'] = next(s for s in raw_post_attribute.strings if s in [
            'Fall', 'Winter', 'Spring'])
        # Original duration string has a trailing space
        post['duration'] = next(
            s.strip() for s in raw_post_attribute.strings if re.match('^\\d+ Month', s))
        post['type'] = next(s for s in raw_post_attribute.strings if s in [
                            'Coed', 'Male Only', 'Female Only'])

        return post
    # StopIteration is raised when next() can't find a match
    except StopIteration:
        # TODO: Handle error better
        return {}


def lambda_handler(event, context) -> List[Post]:
    webpage_response = requests.get('https://bamboohousing.ca/homepage')
    webpage = webpage_response.content
    soup = BeautifulSoup(webpage, 'html.parser')

    # TODO: check if # of posts = # of attributes
    raw_posts = soup.find_all(class_='mobiletitle')
    raw_post_attributes = soup.find_all(class_='desktoplistinglabels')

    posts = [parse_raw_post(raw_post, raw_post_attribute)
             for raw_post, raw_post_attribute in zip(raw_posts, raw_post_attributes)]

    for post in posts:
        if post:
            _ = db_client.put_item(TableName='bamboohousing', Item=post)

    return posts


if __name__ == '__main__':
    # Logging
    import logging
    logging.basicConfig(filename='lambda_function.log', level=logging.INFO)
    #

    logging.info(lambda_handler(None, None))
