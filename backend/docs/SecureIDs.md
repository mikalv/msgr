# SecureID

## Facts

* We use time to be able to have a sequential ID
    * 23 bits for time in milliseconds (gives us 23 years of IDs with a custom epoch)
        * What's the issue with this is SORTING. To be able to tell that;
        * `M:79E4E7:508Q4AKN` is an older ID than `M:79E4F1:ev8d6qlk`
        * In other words:
            * `( M:79E4E7:508Q4AKN < M:79E4F1:ev8d6qlk ) == True`
* There shoudn't be a max number for the ID
    * ID string will get larger when number exceed a digit between:
    * somewhere between 10,000,000,000 to 1,000,000,000,000
* Can have Prefix aka type.
    * M can be a message ID
    * C can be a conversation ID
    * R can be a room ID
    * T can be a team ID
    * U can be a user ID
    * P can be a profile ID

## Example IDs

Here is a bunch:

```
M:79E4E7:2W8gRAOy
M:79E4E7:Eda7b8zG
M:79E4E7:508Q4AKN
M:79E4E8:6kA4Yj8b
M:79E4E8:nXAw2Klo
M:79E4E8:kq8WgN8R
M:79E4E8:L18zz98B
M:79E4E9:rJ89q58N
M:79E4E9:L4amqMae
M:79E4E9:dNa0JNA2
M:79E4E9:OZ8JmBAJ
M:79E4E9:po8MnyaJ
M:79E4F1:zVaR0jAL
M:79E4F1:ev8d6qlk
M:79E4F1:4nl5v1Ar
M:79E4F1:yKAq71aj
M:79E4F1:wnAPXRAP
```



## Usage example

```
iex(96)> Teams.SecureID.id!(1)
"M:72D98F:M7aEBl5d"
iex(97)> Teams.SecureID.id!(2)
"M:72E108:gYapO8vZ"
iex(98)> Teams.SecureID.id!(3)
"M:72E807:vMaKGa1d"
iex(99)> tre = Teams.SecureID.id!(3)
"M:730332:vMaKGa1d"
iex(100)> Teams.SecureID.revert_id(tre)
%{id: 3, prefix: "M", tid: 7537458, real_time: 1734843642}
iex(101)>
```

## How it works?

This works because we have a constant `1727306184` which is epoch for `Thursday, 26 September 2024 01:16:24 GMT+02:00 DST`.

The logic is as following;
take millisecond since `1st Jan 1970 00:00:00` and substract the constant above, and we "reboot" it. The number is
milliseconds since `26th Sep 2024 01:16:24`. We can then also do a addition on the numbers when reverting, and then
have the possibility to extract the time the ID was generated in normal epoch unix timestamp.

### HashIDs

Hashids works similarly to the way integers are converted to hex, but with a few exceptions:

* The alphabet is not base16, but base base62 by default.
* The alphabet is also shuffled based on salt.

This JavaScript function shows regular conversion of integers to hex. It's part of Hashids (although this is a modified example):

```javascript

function toHex(input) {
  var hash = "",
    alphabet = "0123456789abcdef",
    alphabetLength = alphabet.length;
  do {
    hash = alphabet[input % alphabetLength] + hash;
    input = parseInt(input / alphabetLength, 10);
  } while (input);
  return hash;
}
```

If we try to convert integer 1234 to hex with toHex(1234), we will get back "4d2".

If we increase the alphabet to abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890, our output will now be shorter because there's more characters to work with — so it becomes "t5".

If we take it one step further and shuffle the alphabet before encoding, we will get a different value. But how could we shuffle the alphabet consistently, so that with every shuffle the characters would keep the same order?

That's where Hashids uses a variation of [Fisher-Yates algorithm](https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle):

```javascript
function consistentShuffle(alphabet, salt) {

  var integer, j, temp, i, v, p;

  for (i = alphabet.length - 1, v = 0, p = 0; i > 0; i--, v++) {

    v %= salt.length;
    p += integer = salt[v].charCodeAt(0);
    j = (integer + v + p) % i;

    temp = alphabet[j];
    alphabet = alphabet.substr(0, j) + alphabet[i] + alphabet.substr(j + 1);
    alphabet = alphabet.substr(0, i) + temp + alphabet.substr(i + 1);

  }

  return alphabet;

}
```

The code above might look complicated, but it does one simple thing — shuffles the alphabet based on user's salt.

That way when one user passes the salt "abc1", our alphabet becomes `cUpI6isqCa0brWZnJA8wNTzDHEtLXOYgh5fQm2uRj4deM91oB7FkSGKxvyVP3l`

And when another user passes "abc2", the alphabet becomes `tRvkhHx0ZefcF46YuaAqGLDKgM1W5Vp2T8n9s7BSoCjiQOdrEbJmUINywzXP3l`

You can see that the shuffle is pretty good even when salt value is not that much different. This is what makes the base of Hashids work. Now we are able to encode one integer based on the salt value the user provides.

But Hashids is able to encode several integers into one id. This is done by reserving a few characters from the alphabet as separators. These characters are not used in encoding, but instead do the job of purely separating the real encoded values.

Let's say we encoded 1, 2, 3 without the salt and got "o2fXhV". Actual values in this output are highlighted: o**2**f**X**h**V**. Letters "f" and "h" are simply used as separators.

Letter "o" in this case is reserved for another type of job - it acts as a lottery character to randomize incremental input. If we encode numbers as we increment them, the output is somewhat predictable:


| Input | Output |
|:--------:|:-:|
| 1, 2, 3  |  2fXhV  |
| 1, 2, 4  |  2fXhd  |
| 1, 2, 5  |  2fXh6 |
| 1, 2, 6  |  2fXhz  |
| 1, 2, 7  |  2fXhR  |

So the lottery character is used to do another iteration of consistent shuffle, before starting the actual encoding. The ids then end up looking more random (with a tiny disadvantage of having that extra lottery character):

| Input | Output |
|:--------:|:-:|
| 1, 2, 3  |  o2fXhV  |
| 1, 2, 4  |  pYfzhG  |
| 1, 2, 5  |  qxfOhN |
| 1, 2, 6  |  rkfAhN  |
| 1, 2, 7  |  v2fWhy  |

This is a quick overview of how Hashids is structured. Decoding is done the same way but in reverse — of course in order for that to work, Hashids itself needs the salt value from you in order to decode ids correctly.

If you give Hashids the wrong salt and it just so happens that it decodes back to some random integers, Hashids does a quick check by encoding those integers to be sure the initial id matches. If it does not, the integers are discarded.


### Ideas (partly implemented)

Generate ids based on timestamp. If you can afford certain degree of collisions, you could compose an id that's built on the fly. Use a counter (if you have one) + timestamp (even better if in milliseconds) + some system value (either an IP address or some machine id) + a random integer. Many big companies implement this approach because it works well in distributed systems. These ids are generated independently of each other and the risk of collisions is so tiny it's negligible.

## References

* Twitter's snowflake
* ULID
* UUID6
* https://github.com/alco/hashids-elixir

## Inspiration

* https://instagram-engineering.com/sharding-ids-at-instagram-1cf5a71e5a5c
* https://www.mongodb.com/docs/manual/reference/method/ObjectId/
* https://code.flickr.net/2010/02/08/ticket-servers-distributed-unique-primary-keys-on-the-cheap/
